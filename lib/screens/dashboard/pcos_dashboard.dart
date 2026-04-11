import 'package:flutter/material.dart';
import '../logs/calendar_screen.dart';
import '../report/reports_screen.dart';
import '../chatbot/chatbot_screen.dart';
import '../diet/diet_planner_screen.dart';
import '../step_tracker/step_tracker_screen.dart';
import '../../widgets/health_metrics_chart.dart';

import '../onboarding/condition_selection_screen.dart';

class PCOSDashboard extends StatelessWidget {
  final String userName;
  final String conditionLabel;
  final double? weight;
  final int? cycleDay;
  final int? nextPeriodDays;
  final String? nextPeriodDateStr;
  final String? phaseName;
  final bool? isIrregular;
  final int todaySteps;
  final Function(int) onTabChange;

  const PCOSDashboard({
    super.key,
    required this.userName,
    required this.conditionLabel,
    this.weight,
    this.cycleDay,
    this.nextPeriodDays,
    this.nextPeriodDateStr,
    this.phaseName,
    this.isIrregular,
    required this.todaySteps,
    required this.onTabChange,
  });

  LinearGradient _getPhaseGradient() {
    final phase = phaseName ?? '';
    if (phase.contains('Menstrual')) {
      return const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFB5616A), Color(0xFF8E4A50)],
      );
    } else if (phase.contains('Ovulation')) {
      return const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF88C0D0), Color(0xFF81A1C1)],
      );
    } else if (phase.contains('Luteal')) {
      return const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFD08770), Color(0xFFA36D5A)],
      );
    } else if (phase.contains('Follicular')) {
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── App Bar ──────────────────────────────────────────────
        SafeArea(
          bottom: false,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 10, 20, 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Image.asset(
                  'assets/images/logo/logo.png',
                  width: 32,
                  height: 32,
                ),
                const SizedBox(width: 10),
                Text(
                  'Sakhi – $conditionLabel',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2E4A6B),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Scrollable Content ────────────────────────────────────
        Expanded(
          child: ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
         const SizedBox(height: 22),

        // ── Greeting ─────────────────────────────────────────
        Text(
          'Hello, $userName',
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
              conditionLabel,
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
                cycleDay != null ? 'Cycle Day $cycleDay' : 'Cycle Day --',
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
                  Column(
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
                        nextPeriodDays != null
                            ? (nextPeriodDays! < 0
                                ? 'Late by ${-nextPeriodDays!} days'
                                : '$nextPeriodDays Days')
                            : '-- Days',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      if (nextPeriodDateStr != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Est. $nextPeriodDateStr',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white70,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
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
                      phaseName ?? 'Tracking',
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
                value: weight != null
                    ? '${weight!.toStringAsFixed(1)} kg'
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
                  value: '$todaySteps',
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
          childAspectRatio: 0.82, // Balanced for 4-column layout
          children: [
            _quickAction(
              icon: Icons.calendar_month_outlined,
              label: 'Log Period',
              color: const Color(0xFFB5616A),
              bgColor: const Color(0xFFFFECEC),
              onTap: () async {
                final index = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CalendarScreen()),
                );
                if (index is int) onTabChange(index);
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
                  MaterialPageRoute(builder: (context) => const ReportsScreen()),
                );
                if (index is int) onTabChange(index);
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

        const SizedBox(height: 32),
        const Text(
          'Health Trends',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1A2B3C),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 16),
        const HealthMetricsChart(),

        const SizedBox(height: 30),
      ],
    ), // ListView
        ), // Expanded
      ],
    ); // Column
  }

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
