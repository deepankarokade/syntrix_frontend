import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../insights/pregnancy_insights_screen.dart';
import '../onboarding/condition_selection_screen.dart';
import '../chatbot/chatbot_screen.dart';
import '../diet/diet_planner_screen.dart';
import '../step_tracker/step_tracker_screen.dart';
import '../medicine/medicine_management_screen.dart';
import '../../services/step_tracker_service.dart';
import '../../services/blood_sugar_service.dart';
import '../../services/pregnancy_log_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PregnancyDashboard extends StatefulWidget {
  final String userName;
  final String conditionLabel;
  final String trimester;
  final double? weight;
  final int todaySteps;
  final Function(int) onTabChange;

  const PregnancyDashboard({
    super.key,
    required this.userName,
    required this.conditionLabel,
    required this.trimester,
    this.weight,
    required this.todaySteps,
    required this.onTabChange,
  });

  @override
  State<PregnancyDashboard> createState() => _PregnancyDashboardState();
}

class _PregnancyDashboardState extends State<PregnancyDashboard> {
  double? _localWeight;
  String conditionLabel = "Pregnancy Care";
  String userName = "User";
  String trimester = "";
  int _todaySteps = 0;
  final StepTrackerService _stepService = StepTrackerService();
  StreamSubscription? _stepSubscription;

  // Blood sugar data
  double _lastBloodSugar = 94.0;
  String _lastBloodSugarType = 'Pre-meal';
  bool _isLoadingBloodSugar = true;

  int _currentWeek = 20;

  @override
  void initState() {
    super.initState();
    conditionLabel = widget.conditionLabel;
    userName = widget.userName;
    trimester = widget.trimester;
    _localWeight = widget.weight;
    _loadData();
    _initializeStepTracker();
    _fetchLatestBloodSugar();
  }

  Future<void> _fetchLatestBloodSugar() async {
    try {
      final reading = await BloodSugarService.getLatestReading();
      if (reading != null && mounted) {
        setState(() {
          _lastBloodSugar = (reading['value'] as num).toDouble();
          _lastBloodSugarType = reading['type'] ?? 'Pre-meal';
          _isLoadingBloodSugar = false;
        });
      } else {
        if (mounted) setState(() => _isLoadingBloodSugar = false);
      }
    } catch (e) {
      debugPrint('Error fetching blood sugar: $e');
      if (mounted) setState(() => _isLoadingBloodSugar = false);
    }
  }

  void _showAddBloodSugarDialog() {
    final TextEditingController controller =
        TextEditingController(text: _lastBloodSugar.toString());
    String selectedType = 'Fasting';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Log Blood Sugar'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Reading (mg/dL)',
                  hintText: 'e.g. 95',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedType,
                items: ['Fasting', 'Post-meal', 'Random']
                    .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setDialogState(() => selectedType = val);
                },
                decoration: const InputDecoration(
                    labelText: 'Type', border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final val = double.tryParse(controller.text);
                if (val != null) {
                  await BloodSugarService.saveReading(
                    value: val,
                    type: selectedType,
                    date: DateTime.now(),
                  );
                  _fetchLatestBloodSugar();
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Blood sugar logged successfully!')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3A6EA8),
                  foregroundColor: Colors.white),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _initializeStepTracker() async {
    await _stepService.initialize();

    // Listen to step count updates
    _stepSubscription = _stepService.stepCountStream.listen((steps) {
      if (mounted) {
        setState(() {
          _todaySteps = steps;
        });
      }
    });

    // Get initial step count
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

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();

    // Load weight
    final savedWeight = prefs.getDouble('userWeight');

    // Load trimester if empty
    String? savedTrimester;
    if (trimester.isEmpty) {
      savedTrimester = prefs.getString('selectedTrimester');
    }

    int week = prefs.getInt("pregnancyWeek") ?? 20;

    if (mounted) {
      setState(() {
        if (savedWeight != null) _localWeight = savedWeight;
        if (savedTrimester != null) trimester = savedTrimester;
        _currentWeek = week;
      });
    }

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final info = await PregnancyLogService.getPregnancyInfo(uid);
        if (mounted && info['currentWeek'] != null) {
          setState(() {
            _currentWeek = info['currentWeek']!;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading pregnancy info: $e');
    }
  }

  String _getBabySizeForWeek(int week) {
    if (week <= 4) return 'Poppy Seed';
    if (week <= 6) return 'Sweet Pea';
    if (week <= 8) return 'Raspberry';
    if (week <= 10) return 'Prune';
    if (week <= 12) return 'Lime';
    if (week <= 14) return 'Lemon';
    if (week <= 16) return 'Avocado';
    if (week <= 18) return 'Bell Pepper';
    if (week <= 20) return 'Banana';
    if (week <= 22) return 'Papaya';
    if (week <= 24) return 'Corn on the Cob';
    if (week <= 26) return 'Lettuce';
    if (week <= 28) return 'Eggplant';
    if (week <= 30) return 'Coconut';
    if (week <= 32) return 'Squash';
    if (week <= 34) return 'Pineapple';
    if (week <= 36) return 'Honeydew Melon';
    if (week <= 38) return 'Pumpkin';
    return 'Watermelon';
  }

  String _getBabyImageForWeek(int week) {
    // Map weeks to phase images (1-16)
    // Weeks 1-40 mapped to 16 phases
    int phase = ((week - 1) / 2.5).floor() + 1;
    phase = phase.clamp(1, 16);
    return 'lib/resources/assets/pregnancy/phase_$phase.png';
  }

  String _getBabyLengthForWeek(int week) {
    if (week <= 4) return '< 1 cm';
    if (week <= 8) return '1.5–2 cm';
    if (week <= 12) return '5–7 cm';
    if (week <= 16) return '11–12 cm';
    if (week <= 20) return '25–26 cm';
    if (week <= 24) return '30–32 cm';
    if (week <= 28) return '37–38 cm';
    if (week <= 32) return '42–43 cm';
    if (week <= 36) return '47–48 cm';
    return '50+ cm';
  }

  void onTabChange(int index) {
    widget.onTabChange(index);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        const SizedBox(height: 24),

        // ── Top bar ──────────────────────────────────────────
        Row(
          children: [
            Image.asset(
              'assets/images/logo/logo.png',
              width: 28,
              height: 28,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Sakhi – $conditionLabel',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2E4A6B),
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            const SizedBox(width: 4),
            InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const ConditionSelectionScreen(),
                  ),
                );
              },
              child: const Padding(
                padding: EdgeInsets.all(8.0),
                child: Icon(
                  Icons.swap_horiz,
                  size: 20,
                  color: Color(0xFF7A8FA6),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 22),

        // ── Greeting ─────────────────────────────────────────
        Text(
          'Welcome, $userName',
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1A2B3C),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          trimester.isNotEmpty ? trimester : 'Week 20 • Halfway there!',
          style: const TextStyle(
            fontSize: 16,
            color: Color(0xFF7A8FA6),
            fontWeight: FontWeight.w500,
          ),
        ),

        const SizedBox(height: 24),

        // ── Blood Sugar Status Card ──────────────────────────
        GestureDetector(
          onTap: _showAddBloodSugarDialog,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'BLOOD SUGAR STATUS',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF3A6EA8),
                        letterSpacing: 0.5,
                      ),
                    ),
                    Icon(Icons.add_circle_outline, color: Colors.blue[800], size: 20),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      _lastBloodSugar.toStringAsFixed(0),
                      style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A2B3C),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'mg/dL',
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFF7A8FA6),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      _lastBloodSugar < 140 ? Icons.check_circle : Icons.warning_rounded,
                      color: _lastBloodSugar < 140 ? Colors.green : Colors.orange,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _lastBloodSugar < 140 
                        ? 'In target range ($_lastBloodSugarType)' 
                        : 'Above target range ($_lastBloodSugarType)',
                      style: const TextStyle(fontSize: 14, color: Color(0xFF7A8FA6)),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: (_lastBloodSugar / 200 * 10).round().clamp(1, 10),
                        child: Container(
                          height: 28,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: _lastBloodSugar < 140 
                                ? [const Color(0xFF3A6EA8), const Color(0xFF6A9ED8)]
                                : [Colors.orange, Colors.deepOrangeAccent],
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 12),
                          child: Text(
                            _lastBloodSugar < 140 ? 'Stable' : 'High',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 10 - (_lastBloodSugar / 200 * 10).round().clamp(1, 10),
                        child: const SizedBox()
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // ── Baby's Size Card ─────────────────────────────────
        Builder(
          builder: (context) {
            String babySize = _getBabySizeForWeek(_currentWeek);
            String babyLength = _getBabyLengthForWeek(_currentWeek);
            String babyImage = _getBabyImageForWeek(_currentWeek);

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F8FB),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4AC2CD).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: ClipOval(
                        child: Image.asset(
                          babyImage,
                          width: 70,
                          height: 70,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              Icons.baby_changing_station,
                              size: 40,
                              color: Color(0xFF4AC2CD),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Your Baby's Size",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1A2B3C),
                          ),
                        ),
                        const SizedBox(height: 4),
                        RichText(
                          text: TextSpan(
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF7A8FA6),
                            ),
                            children: [
                              const TextSpan(text: 'Baby is as big as a '),
                              TextSpan(
                                text: babySize,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF1A2B3C),
                                ),
                              ),
                              TextSpan(text: ' ($babyLength).'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.red.withValues(alpha: 0.2),
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'VITALITY PHASE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFB5616A),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.face_retouching_natural,
                    color: Colors.grey,
                    size: 40,
                  ),
                ],
              ),
            );
          },
        ),

        const SizedBox(height: 16),

        // ── Weight & Activity Row ────────────────────────────
        Row(
          children: [
            Expanded(
              child: _smallCard(
                icon: Icons.monitor_weight,
                iconColor: Colors.brown,
                label: 'WEIGHT',
                value: _localWeight != null
                    ? '${_localWeight!.toStringAsFixed(1)} kg'
                    : 'Add weight',
                subValue: _localWeight != null ? '+0.2kg this week' : null,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _smallCard(
                icon: Icons.directions_run,
                iconColor: Colors.teal,
                label: 'ACTIVITY',
                value: _todaySteps > 0
                    ? '${_todaySteps.toStringAsFixed(0)} steps'
                    : '0 steps',
                showProgress: true,
                progressValue: _todaySteps / 8000,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const StepTrackerScreen(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        const SizedBox(height: 8),

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
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: _quickAction(
                icon: Icons.auto_awesome,
                label: 'AI\nInsights',
                color: const Color(0xFF3A6EA8),
                bgColor: const Color(0xFFE8F0F8),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PregnancyInsightsScreen(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _quickAction(
                icon: Icons.chat_bubble_outline,
                label: 'AI Chat',
                color: const Color(0xFFB5616A),
                bgColor: const Color(0xFFFFECEC),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ChatbotScreen(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _quickAction(
                icon: Icons.restaurant_menu,
                label: 'Meal\nPlan',
                color: const Color(0xFF2E7D6B),
                bgColor: const Color(0xFFE0F4F0),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const DietPlannerScreen(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _quickAction(
                icon: Icons.medication,
                label: 'Medicine',
                color: const Color(0xFFE67E22),
                bgColor: const Color(0xFFFFF3E0),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MedicineManagementScreen(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: 30),
      ],
    );
  }

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
        height: 110,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withValues(alpha: 0.85),
              color,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 28),
            const SizedBox(height: 8),
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _smallCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    String? subValue,
    bool showProgress = false,
    double? progressValue,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: iconColor, size: 24),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Color(0xFF7A8FA6),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A2B3C),
              ),
            ),
            if (subValue != null) ...[
              const SizedBox(height: 4),
              Text(
                subValue,
                style: const TextStyle(fontSize: 11, color: Color(0xFF7A8FA6)),
              ),
            ],
            if (showProgress) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: progressValue != null
                      ? progressValue.clamp(0.0, 1.0)
                      : 0.6,
                  backgroundColor: Colors.grey[100],
                  color: Colors.teal,
                  minHeight: 4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
