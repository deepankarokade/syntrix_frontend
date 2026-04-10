import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../insights/insights_screen.dart';
import '../logs/calendar_screen.dart';
import '../report/reports_screen.dart';
import '../logs/log_entry_screen.dart';
import '../profile/profile_screen.dart';
import '../../widgets/custom_bottom_nav.dart';
import '../../services/user_session.dart';
import '../chatbot/chatbot_screen.dart';
import '../diet/diet_planner_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentTab = 0;
  String _userName = '';
  String _conditionLabel = 'General Tracking';
  double? _weight;
  bool _loadingUser = true;

  // Condition value → display tag map
  static const _conditionTags = {
    'pcos': 'PCOS Management',
    'pregnant': 'Pregnancy Tracking',
    'menopause': 'Menopause Support',
    'none': 'General Tracking',
  };

  @override
  void initState() {
    super.initState();
    _loadUserData();
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
          _conditionLabel = _conditionTags[stage] ?? 'General Tracking';
          _weight = weightVal;
        });
      }
    } catch (e) {
      print('Home: Error loading user data: $e');
    } finally {
      if (mounted) {
        setState(() => _loadingUser = false);
        print('Home: Loading complete, user: $_userName');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine which screen to show based on the current tab
    Widget currentBody;

    switch (_currentTab) {
      case 1:
        currentBody = const InsightsScreen();
        break;
      case 2:
        currentBody = const LogEntryScreen();
        break;
      case 3:
        currentBody = const ProfileScreen();
        break;
      default:
        currentBody = _buildHomeContent();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      body: currentBody,
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: _currentTab,
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
                  // mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Serene Cycle',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2E4A6B),
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
                    Text(
                      _conditionLabel,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF7A8FA6),
                        fontWeight: FontWeight.w500,
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
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF3A6EA8), Color(0xFF2E4A6B)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF3A6EA8).withValues(alpha: 0.3),
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
                      const Text(
                        'Cycle Day 12',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Next Period',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white60,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                '16 Days',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'Follicular Phase',
                              style: TextStyle(
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
                      child: _statCard(
                        icon: Icons.bolt,
                        iconColor: const Color(0xFFB5616A),
                        label: 'Energy',
                        value: 'Low',
                        valueColor: const Color(0xFFB5616A),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // ── Insight card ──────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF0F0),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFFFD0D0),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFE5E5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.warning_amber_rounded,
                          color: Color(0xFFB5616A),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Insight Detected',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1A2B3C),
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Cycle irregularity detected. This can be common with PCOS; consider tracking your cortisol levels this week.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF7A8FA6),
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
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

                const SizedBox(height: 24),

                // ── Recommended for you ───────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Recommended for you',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A2B3C),
                      ),
                    ),
                    TextButton(
                      onPressed: () {},
                      child: const Text(
                        'View All',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF3A6EA8),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 200,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _recommendCard(
                        tag: '15 MIN',
                        title: 'Morning Yoga',
                        subtitle: 'Gentle flow for cortisol balance',
                        gradient: const LinearGradient(
                          colors: [Color(0xFF3A6EA8), Color(0xFF2E4A6B)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        icon: Icons.self_improvement,
                      ),
                      _recommendCard(
                        tag: 'NUTRITION',
                        title: 'Low Glycemic Diet',
                        subtitle: 'Stabilize blood sugar naturally',
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2E7D6B), Color(0xFF1A5C4E)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        icon: Icons.restaurant_outlined,
                      ),
                    ],
                  ),
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
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF3D5166),
              fontWeight: FontWeight.w500,
              height: 1.3,
            ),
          ),
        ],
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
