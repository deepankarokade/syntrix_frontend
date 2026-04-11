import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../insights/insights_screen.dart';
import '../insights/pregnancy_insights_screen.dart';
import '../insights/menopause_insights_screen.dart';
import '../logs/calendar_screen.dart';
import '../logs/pregnancy_log_screen.dart';
import '../report/reports_screen.dart';
import '../logs/log_entry_screen.dart';
import '../profile/profile_screen.dart';
import '../../widgets/custom_bottom_nav.dart';
import '../../services/user_session.dart';
import '../../services/cycle_prediction_service.dart';
import '../chatbot/chatbot_screen.dart';
import '../diet/diet_planner_screen.dart';
import '../dashboard/pcos_dashboard.dart';
import '../dashboard/pregnancy_dashboard.dart';
import '../dashboard/menopause_dashboard.dart';
import '../step_tracker/step_tracker_screen.dart';
import '../../services/step_tracker_service.dart';
import 'dart:async';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentTab = 0;
  String _userName = '';
  String _conditionLabel = 'General Tracking';
  String _lifeStage = 'none';
  String _trimester = '';
  double? _weight;
  bool _loadingUser = true;

  int? _cycleDay;
  int? _nextPeriodDays;
  String? _nextPeriodDateStr;
  String _phaseName = 'Follicular Phase';
  bool _isIrregular = false;

  // Condition value → display tag map
  static const _conditionTags = {
    'pcos': 'PCOS Management',
    'pregnant': 'Pregnancy Tracking',
    'menopause': 'Menopause Support',
    'none': 'General Tracking',
  };

  int _todaySteps = 0;
  final StepTrackerService _stepService = StepTrackerService();
  StreamSubscription? _stepSubscription;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _initializeStepTracker();
  }

  Future<void> _initializeStepTracker() async {
    await _stepService.initialize();
    _stepSubscription = _stepService.stepCountStream.listen((steps) {
      if (mounted) {
        setState(() {
          _todaySteps = steps;
        });
      }
    });
    if (mounted) {
      setState(() {
        _todaySteps = _stepService.todaySteps;
      });
    }
  }

  @override
  void dispose() {
    _stepSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    print('Home: Loading user data...');
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('Home: No user found in Auth');
        if (mounted) setState(() => _loadingUser = false);
        return;
      }

      // Initial fallback to Auth data
      _userName = (user.displayName ?? '').split(' ').first;
      if (_userName.isEmpty) _userName = 'User';

      print('Home: Fetching doc for UID: ${user.uid}');

      // Fetch the user document using the UID
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists && mounted) {
        final data = doc.data()!;
        print('Home: Doc exists, data: $data');

        // Extract values
        final nameStr = data['name'] as String? ?? '';
        final stage = data['lifeStage'] as String? ?? 'none';
        final weightVal = data['weight'] != null
            ? (data['weight'] as num).toDouble()
            : null;
        final heightVal = data['height'] != null
            ? (data['height'] as num).toDouble()
            : null;
        final photoUrl = data['photoUrl'] as String?;

        String formattedDob = "--";
        if (data['dob'] != null) {
          final Timestamp ts = data['dob'];
          final DateTime dt = ts.toDate();
          final months = [
            'Jan',
            'Feb',
            'Mar',
            'Apr',
            'May',
            'Jun',
            'Jul',
            'Aug',
            'Sep',
            'Oct',
            'Nov',
            'Dec',
          ];
          formattedDob = "${months[dt.month - 1]} ${dt.day}, ${dt.year}";
        }

        // Update static cache
        UserSession.update(
          newName: nameStr.isNotEmpty ? nameStr : user.displayName,
          newWeight: weightVal?.toString(),
          newHeight: heightVal?.toString(),
          newCondition: _conditionTags[stage] ?? 'General Tracking',
          newDob: formattedDob,
          newPhotoUrl: photoUrl,
        );

        setState(() {
          if (nameStr.isNotEmpty) {
            _userName = nameStr.split(' ').first;
          }
          _lifeStage = stage;
          _trimester = data['trimester'] as String? ?? '';
          _conditionLabel = _conditionTags[stage] ?? 'General Tracking';
          _weight = weightVal;
        });
      }
      
      await _fetchCycleData(user.uid);
    } catch (e) {
      print('Home: Error loading user data: $e');
    } finally {
      if (mounted) {
        setState(() => _loadingUser = false);
        print('Home: Loading complete, user: $_userName');
      }
    }
  }

  Future<void> _fetchCycleData(String uid) async {
    try {
      final cycleData = await CyclePredictionService.getCycleData(uid);
      if (mounted) {
        setState(() {
          _cycleDay = cycleData.cycleDay;
          if (cycleData.daysToNextPeriod < 0) {
            _nextPeriodDays = 0;
          } else {
            _nextPeriodDays = cycleData.daysToNextPeriod;
          }
          _nextPeriodDateStr = DateFormat('MMM dd, yyyy').format(cycleData.nextPeriodDate);
          _phaseName = cycleData.phaseName;
          _isIrregular = cycleData.isIrregular;
        });
      }
    } catch (e) {
      print('Home: Error loading cycle data: \$e');
    }
  }

  LinearGradient _getPhaseGradient() {
    if (_phaseName.contains('Menstrual')) {
      return const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFB5616A), Color(0xFF8E4A50)],
      );
    } else if (_phaseName.contains('Ovulation')) {
      return const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF88C0D0), Color(0xFF81A1C1)],
      );
    } else if (_phaseName.contains('Luteal')) {
      return const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFD08770), Color(0xFFA36D5A)],
      );
    } else if (_phaseName.contains('Follicular')) {
      return const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFA3BE8C), Color(0xFF88C0CB)],
      );
    }
    // Default
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF3A6EA8), Color(0xFF2E4A6B)],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Determine which screen to show based on the current tab
    Widget currentBody;

    switch (_currentTab) {
      case 1:
        // For pregnant users, show Pregnancy AI Insights instead of generic Insights
        if (_lifeStage == 'pregnant') {
          currentBody = const PregnancyInsightsScreen();
        } else if (_lifeStage == 'menopause') {
          currentBody = const MenopauseInsightsScreen();
        } else {
          currentBody = const InsightsScreen();
        }
        break;
      case 2:
        // For pregnant users, show Pregnancy Lifestyle Log instead of generic Add Log
        if (_lifeStage == 'pregnant') {
          currentBody = const PregnancyLogScreen();
        } else {
          currentBody = const LogEntryScreen();
        }
        break;
      case 3:
        currentBody = ProfileScreen(
          onBack: () => setState(() => _currentTab = 0),
        );
        break;
      default:
        if (_lifeStage == 'pcos') {
          currentBody = PCOSDashboard(
            userName: _userName,
            conditionLabel: _conditionLabel,
            weight: _weight,
            cycleDay: _cycleDay,
            nextPeriodDays: _nextPeriodDays,
            nextPeriodDateStr: _nextPeriodDateStr,
            phaseName: _phaseName,
            isIrregular: _isIrregular,
            todaySteps: _todaySteps,
            onTabChange: (index) => setState(() => _currentTab = index),
          );
        } else if (_lifeStage == 'pregnant') {
          currentBody = PregnancyDashboard(
            userName: _userName,
            conditionLabel: _conditionLabel,
            trimester: _trimester,
            weight: _weight,
            todaySteps: _todaySteps,
            onTabChange: (index) => setState(() => _currentTab = index),
          );
        } else if (_lifeStage == 'menopause') {
          currentBody = MenopauseDashboard(
            userName: _userName,
            conditionLabel: _conditionLabel,
            weight: _weight,
            todaySteps: _todaySteps,
            onTabChange: (index) => setState(() => _currentTab = index),
          );
        } else {
          currentBody = _buildHomeContent();
        }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      body: currentBody,
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: _currentTab,
        lifeStage: _lifeStage,
        onTap: (index) {
          setState(() {
            _currentTab = index;
          });
        },
      ),
    );
  }

  // ── Original Home Content extracted for tab switching ───────────
  Widget _buildHomeContent() {
    return SafeArea(
      child: _loadingUser
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                const SizedBox(height: 18),

                // ── Top bar ──────────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Serene Cycle',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2E4A6B),
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 22),

                // ── Greeting ─────────────────────────────────────────
                Text(
                  'Hello, $_userName',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A2B3C),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFFB5616A),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _conditionLabel,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF7A8FA6),
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // ── Current Status card ───────────────────────────────
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    gradient: _getPhaseGradient(),
                    boxShadow: [
                      BoxShadow(
                        color: _getPhaseGradient().colors.first.withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'CURRENT STATUS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white60,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _cycleDay != null ? 'Cycle Day $_cycleDay' : 'Cycle Day 12',
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Next Period',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.white60,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _nextPeriodDays != null
                                      ? (_nextPeriodDays! < 0
                                          ? 'Late by ${-_nextPeriodDays!} days'
                                          : '$_nextPeriodDays Days')
                                      : '-- Days',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    height: 1.3,
                                  ),
                                ),
                                if (_nextPeriodDateStr != null && _nextPeriodDateStr!.isNotEmpty)
                                  Text(
                                    'Est. $_nextPeriodDateStr',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.white70,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _phaseName,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── Stats row ─────────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: _statCard(
                        icon: Icons.monitor_weight_outlined,
                        iconColor: const Color(0xFF3A6EA8),
                        label: 'Weight',
                        value: _weight != null
                            ? '${_weight!.toStringAsFixed(1)} kg'
                            : '-- kg',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const StepTrackerScreen()),
                          );
                        },
                        child: _statCard(
                          icon: Icons.directions_run,
                          iconColor: const Color(0xFF2E7D6B),
                          label: 'Activity',
                          value: '$_todaySteps',
                          valueColor: const Color(0xFF2E7D6B),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),


                // ── Quick Actions ─────────────────────────────────────
                const Text(
                  'QUICK ACTIONS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF7A8FA6),
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 14),
                GridView.count(
                  crossAxisCount: 4,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 0.82,
                  children: [
                    _quickAction(
                      icon: Icons.calendar_month_outlined,
                      label: 'Log Period',
                      color: const Color(0xFFB5616A),
                      bgColor: const Color(0xFFFFECEC),
                      onTap: () async {
                        final index = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const CalendarScreen(),
                          ),
                        );
                        if (index is int && mounted) {
                          setState(() => _currentTab = index);
                        }
                      },
                    ),
                    _quickAction(
                      icon: Icons.upload_file_outlined,
                      label: 'Upload\nReport',
                      color: const Color(0xFF2E7D6B),
                      bgColor: const Color(0xFFE0F4F0),
                      onTap: () async {
                        final index = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ReportsScreen(),
                          ),
                        );
                        if (index is int && mounted) {
                          setState(() => _currentTab = index);
                        }
                      },
                    ),
                    _quickAction(
                      icon: Icons.chat_bubble_outline,
                      label: 'AI Chat',
                      color: const Color(0xFF3A6EA8),
                      bgColor: const Color(0xFFE8F0F8),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const ChatbotScreen()),
                        );
                      },
                    ),
                    _quickAction(
                      icon: Icons.restaurant_menu,
                      label: 'Diet Plan',
                      color: const Color(0xFFD68A3D),
                      bgColor: const Color(0xFFFDF3E9),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const DietPlannerScreen()),
                        );
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 30),
              ],
            ),
    );
  }

  // ── Stat card ────────────────────────────────────────────────────────
  Widget _statCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 18),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: iconColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: valueColor ?? const Color(0xFF1A2B3C),
            ),
          ),
        ],
      ),
    );
  }

  // ── Quick action button ──────────────────────────────────────────────
  Widget _quickAction({
    required IconData icon,
    required String label,
    required Color color,
    required Color bgColor,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 90,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.grey.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF3D5166),
                fontWeight: FontWeight.w500,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Recommended card ─────────────────────────────────────────────────
  Widget _recommendCard({
    required String tag,
    required String title,
    required String subtitle,
    required LinearGradient gradient,
    required IconData icon,
  }) {
    return Container(
      width: 180,
      margin: const EdgeInsets.only(right: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              tag,
              style: const TextStyle(
                fontSize: 10,
                color: Colors.white,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const Spacer(),
          Icon(icon, color: Colors.white54, size: 36),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.75),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
