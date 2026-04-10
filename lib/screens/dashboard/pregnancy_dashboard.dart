import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../insights/pregnancy_insights_screen.dart';
import '../onboarding/condition_selection_screen.dart';
import '../chatbot/chatbot_screen.dart';
import '../diet/diet_planner_screen.dart';

class PregnancyDashboard extends StatefulWidget {
  final String userName;
  final String conditionLabel;
  final String trimester;
  final double? weight;
  final Function(int) onTabChange;

  const PregnancyDashboard({
    super.key,
    required this.userName,
    required this.conditionLabel,
    required this.trimester,
    this.weight,
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

  @override
  void initState() {
    super.initState();
    conditionLabel = widget.conditionLabel;
    userName = widget.userName;
    trimester = widget.trimester;
    _localWeight = widget.weight;
    _loadData();
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
            Text(
              'Serene – $conditionLabel',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2E4A6B),
              ),
            ),
            const Spacer(),
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.settings, color: Color(0xFF2E4A6B)),
            ),
            TextButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const ConditionSelectionScreen()),
                );
              },
              icon: const Icon(Icons.swap_horiz, size: 18, color: Color(0xFF7A8FA6)),
              label: const Text(
                'Switch',
                style: TextStyle(fontSize: 12, color: Color(0xFF7A8FA6)),
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
        Container(
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
                  Icon(Icons.water_drop, color: Colors.blue[800], size: 20),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  const Text(
                    '94',
                    style: TextStyle(
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
                children: const [
                  Icon(Icons.check_circle, color: Colors.green, size: 16),
                  SizedBox(width: 6),
                  Text(
                    'In target range (Pre-meal)',
                    style: TextStyle(fontSize: 14, color: Color(0xFF7A8FA6)),
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
                      flex: 6,
                      child: Container(
                        height: 28,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF3A6EA8), Color(0xFF6A9ED8)],
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 12),
                        child: const Text(
                          'Stable',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const Expanded(flex: 4, child: SizedBox()),
                  ],
                ),
              ),
            ],
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
                value: _localWeight != null ? '${_localWeight!.toStringAsFixed(1)} kg' : 'Add weight',
                subValue: _localWeight != null ? '+0.2kg this week' : null,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _smallCard(
                icon: Icons.directions_run,
                iconColor: Colors.teal,
                label: 'ACTIVITY',
                value: '4,280 steps',
                showProgress: true,
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // ── Hydration Card ───────────────────────────────────
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'HYDRATION',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF3A6EA8),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '1.4L / 2.5L',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A2B3C),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '4 glasses remaining today',
                      style: TextStyle(fontSize: 12, color: Color(0xFF7A8FA6)),
                    ),
                  ],
                ),
              ),
              Row(
                children: List.generate(
                  8,
                  (index) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    width: 6,
                    height: 24,
                    decoration: BoxDecoration(
                      color: index < 5 ? const Color(0xFF2E4A6B) : Colors.grey[200],
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ── Insight card ──────────────────────────────────────
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const PregnancyInsightsScreen()),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F0F8),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: const Color(0xFF3A6EA8).withValues(alpha: 0.2),
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
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: Color(0xFF3A6EA8),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Smart Insight detected',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A2B3C),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Your blood sugar levels are slightly high. Tap to see detailed recommendations.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF7A8FA6),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFF7A8FA6)),
            ],
          ),
        ),
      ),

        const SizedBox(height: 24),

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
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              _quickAction(
                icon: Icons.auto_awesome,
                label: 'AI\nInsights',
                color: const Color(0xFF3A6EA8),
                bgColor: const Color(0xFFE8F0F8),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const PregnancyInsightsScreen()),
                  );
                },
              ),
              const SizedBox(width: 16),
              _quickAction(
                icon: Icons.chat_bubble_outline,
                label: 'AI Chat',
                color: const Color(0xFFB5616A),
                bgColor: const Color(0xFFFFECEC),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ChatbotScreen()),
                  );
                },
              ),
              const SizedBox(width: 16),
              _quickAction(
                icon: Icons.restaurant_menu,
                label: 'Meal Plan',
                color: const Color(0xFF2E7D6B),
                bgColor: const Color(0xFFE0F4F0),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const DietPlannerScreen()),
                  );
                },
              ),
              const SizedBox(width: 16),
              _quickAction(
                icon: Icons.calendar_month,
                label: 'Tracking',
                color: const Color(0xFFD68A3D),
                bgColor: const Color(0xFFFDF3E9),
                onTap: () => onTabChange(2), // 2 is LogEntryScreen
              ),
            ],
          ),
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

  Widget _smallCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    String? subValue,
    bool showProgress = false,
  }) {
    return Container(
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
                value: 0.6,
                backgroundColor: Colors.grey[100],
                color: Colors.teal,
                minHeight: 4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
