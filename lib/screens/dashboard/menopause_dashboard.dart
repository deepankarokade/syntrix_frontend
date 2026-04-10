import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../onboarding/condition_selection_screen.dart';
import '../chatbot/chatbot_screen.dart';
import '../diet/diet_planner_screen.dart';

class MenopauseDashboard extends StatefulWidget {
  final String userName;
  final String conditionLabel;
  final double? weight;
  final Function(int) onTabChange;

  const MenopauseDashboard({
    super.key,
    required this.userName,
    required this.conditionLabel,
    this.weight,
    required this.onTabChange,
  });

  @override
  State<MenopauseDashboard> createState() => _MenopauseDashboardState();
}

class _MenopauseDashboardState extends State<MenopauseDashboard> {
  bool _isLoading = true;
  Map<String, dynamic> _lastLog = {};
  bool _showDoctorAlert = false;

  @override
  void initState() {
    super.initState();
    _fetchLastLog();
  }

  Future<void> _fetchLastLog() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('logs')
          .doc(user.uid)
          .collection('daily_entries')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty && mounted) {
        setState(() {
          _lastLog = snapshot.docs.first.data();
          _checkForAlerts(_lastLog);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print("Error fetching last log: $e");
      setState(() => _isLoading = false);
    }
  }

  void _checkForAlerts(Map<String, dynamic> log) {
    // Alert logic based on requirements
    bool hasBleeding = log['irregularBleeding'] == true || log['spotting'] == true;
    bool severeMood = log['mood'] == '😢' || log['mood'] == '😴';
    
    // Severity check for hot flashes if they exist in log
    int hotFlashSeverity = 0;
    if (log['symptoms'] != null && log['symptoms']['Hot Flashes'] != null) {
      String sev = log['symptoms']['Hot Flashes'];
      if (sev == 'Severe') hotFlashSeverity = 5;
    }

    if (hasBleeding || severeMood || hotFlashSeverity >= 4) {
      setState(() => _showDoctorAlert = true);
    }
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
            Expanded(
              child: Text(
                'Serene – ${widget.conditionLabel}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2E4A6B),
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            const SizedBox(width: 8),
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
          'Hello, ${widget.userName}',
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1A2B3C),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Menopause Support • Daily Check-in',
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF7A8FA6),
            fontWeight: FontWeight.w500,
          ),
        ),

        const SizedBox(height: 24),

        // ── Doctor Alert (If applicable) ──────────────────────
        if (_showDoctorAlert) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF0F0),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFFFD0D0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Color(0xFFB5616A), size: 30),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'MEDICAL NOTICE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFB5616A),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'We noticed unusual symptoms. Please consult a doctor for further evaluation.',
                        style: TextStyle(fontSize: 13, color: Color(0xFF1A2B3C), height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],

        // ── Daily Health Score / Sleep ───────────────────────
        Row(
          children: [
            Expanded(
              child: _statCard(
                icon: Icons.nightlight_round,
                label: 'SLEEP',
                value: _lastLog['sleep'] ?? '7.5 h',
                subValue: 'Good Quality',
                color: const Color(0xFF3A6EA8),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _statCard(
                icon: Icons.thermostat_outlined,
                label: 'HOT FLASHES',
                value: _lastLog['symptoms']?['Hot Flashes'] ?? 'None',
                subValue: 'Reported Today',
                color: const Color(0xFFB5616A),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // ── Physical Wellness ────────────────────────────────
        _wellnessCard(
          icon: Icons.monitor_weight_outlined,
          title: 'Weight Tracking',
          value: widget.weight != null ? '${widget.weight} kg' : 'Add weight',
          progress: 0.65,
          color: Colors.brown[400]!,
        ),

        const SizedBox(height: 24),

        // ── Nutrition Suggestions Header ─────────────────────
        const Text(
          'DIET SUGGESTIONS',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: Color(0xFF7A8FA6),
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 14),

        _dietSuggestionCard(
          title: 'Morning Boost',
          desc: 'Warm water + mixed nuts (Almonds/Walnuts)',
          icon: Icons.wb_twilight,
        ),
        _dietSuggestionCard(
          title: 'Main Meal Focus',
          desc: 'Green veggies + dal + roti (High Calcium & Protein)',
          icon: Icons.restaurant,
        ),
        _dietSuggestionCard(
          title: 'Hydration Goal',
          desc: 'Drink at least 2.5L water. Avoid caffeine after 5 PM.',
          icon: Icons.water_drop,
        ),

        const SizedBox(height: 24),

        // ── Lifestyle Tips ──────────────────────────────────
        const Text(
          'LIFESTYLE RECOMMENDATIONS',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: Color(0xFF7A8FA6),
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 14),

        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _tipCard(
                'Yoga for Stress',
                'Helps manage anxiety and mood swings.',
                Icons.self_improvement,
                const Color(0xFF2E7D6B),
              ),
              _tipCard(
                'Walking 30 min',
                'Essential for bone health and weight.',
                Icons.directions_walk,
                const Color(0xFFD68A3D),
              ),
              _tipCard(
                'Cool Room',
                'Maintains sleep if having night sweats.',
                Icons.ac_unit,
                const Color(0xFF3A6EA8),
              ),
            ],
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
        GridView.count(
          crossAxisCount: 4,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 0.82,
          children: [
            _quickActionButton(
              Icons.edit_calendar_outlined,
              'Log Entry',
              const Color(0xFFB5616A),
              const Color(0xFFFFECEC),
              () => widget.onTabChange(2),
            ),
            _quickActionButton(
              Icons.chat_bubble_outline,
              'AI Chat',
              const Color(0xFF3A6EA8),
              const Color(0xFFE8F0F8),
              () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ChatbotScreen())),
            ),
            _quickActionButton(
              Icons.restaurant_menu,
              'Diet Plan',
              const Color(0xFF2E7D6B),
              const Color(0xFFE0F4F0),
              () => Navigator.push(context, MaterialPageRoute(builder: (context) => const DietPlannerScreen())),
            ),
            _quickActionButton(
              Icons.bar_chart,
              'Reports',
              const Color(0xFFD68A3D),
              const Color(0xFFFDF3E9),
              () => widget.onTabChange(1),
            ),
          ],
        ),

        const SizedBox(height: 40),
      ],
    );
  }

  Widget _statCard({
    required IconData icon,
    required String label,
    required String value,
    required String subValue,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 12),
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF7A8FA6))),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF1A2B3C))),
          const SizedBox(height: 2),
          Text(subValue, style: const TextStyle(fontSize: 10, color: Color(0xFF7A8FA6))),
        ],
      ),
    );
  }

  Widget _wellnessCard({
    required IconData icon,
    required String title,
    required String value,
    required double progress,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1A2B3C))),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: color.withOpacity(0.1),
                    color: color,
                    minHeight: 4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1A2B3C))),
        ],
      ),
    );
  }

  Widget _dietSuggestionCard({required String title, required String desc, required IconData icon}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8F0F8)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF3A6EA8), size: 24),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1A2B3C))),
                const SizedBox(height: 2),
                Text(desc, style: const TextStyle(fontSize: 12, color: Color(0xFF7A8FA6))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tipCard(String title, String desc, IconData icon, Color color) {
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1A2B3C))),
          const SizedBox(height: 4),
          Text(desc, style: const TextStyle(fontSize: 11, color: Color(0xFF7A8FA6))),
        ],
      ),
    );
  }

  Widget _quickActionButton(IconData icon, String label, Color color, Color bgColor, VoidCallback onTap) {
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
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF3D5166),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
