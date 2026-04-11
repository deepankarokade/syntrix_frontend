import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../insights/pregnancy_insights_screen.dart';
import '../onboarding/condition_selection_screen.dart';
import '../chatbot/chatbot_screen.dart';
import '../diet/diet_planner_screen.dart';
import '../step_tracker/step_tracker_screen.dart';
import '../medicine/medicine_management_screen.dart';
import '../logs/pregnancy_log_screen.dart';
import '../../services/step_tracker_service.dart';
import '../../services/blood_sugar_service.dart';

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

    if (mounted) {
      setState(() {
        if (savedWeight != null) _localWeight = savedWeight;
        if (savedTrimester != null) trimester = savedTrimester;
      });
    }
  }

  void onTabChange(int index) {
    widget.onTabChange(index);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        const SizedBox(height: 18),

        // ── Top bar ──────────────────────────────────────────
        Row(
          children: [
            const Icon(Icons.face, size: 24, color: Color(0xFF2E4A6B)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Serene – $conditionLabel',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2E4A6B),
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.settings, color: Color(0xFF2E4A6B)),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
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
            String babySize = 'Pear';
            String babyLength = '25–30 cm';
            String babyIcon = '🍐';

            if (trimester.contains('1st')) {
              babySize = 'Lemon';
              babyLength = '7–8 cm';
              babyIcon = '🍋';
            } else if (trimester.contains('2nd')) {
              babySize = 'Papaya';
              babyLength = '25–30 cm';
              babyIcon = '🥭';
            } else if (trimester.contains('3rd')) {
              babySize = 'Watermelon';
              babyLength = '45–50 cm';
              babyIcon = '🍉';
            }

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
                    decoration: const BoxDecoration(
                      color: Color(0xFF4AC2CD),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        babyIcon,
                        style: const TextStyle(fontSize: 40),
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
        GridView.count(
          crossAxisCount: 3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio:
              0.9, // Adjusted for 3 columns
          children: [
            _quickAction(
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
            _quickAction(
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
            _quickAction(
              icon: Icons.restaurant_menu,
              label: 'Meal Plan',
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
        height: 90,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withValues(alpha: 0.85),
              color,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(width: 10),
            Text(
              label.replaceAll('\n', ' '),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.white,
                fontWeight: FontWeight.w700,
                height: 1.2,
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
