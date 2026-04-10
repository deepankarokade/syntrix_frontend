import 'package:flutter/material.dart';

class CustomBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final String lifeStage;

  const CustomBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.lifeStage = 'none',
  });

  @override
  Widget build(BuildContext context) {
    // Use condition-specific tabs
    final items = (lifeStage == 'pregnant' || lifeStage == 'menopause')
        ? const [
            (Icons.home_filled, 'Home'),
            (Icons.auto_awesome, 'AI Insights'),
            (Icons.edit_note_rounded, 'Lifestyle' ),
            (Icons.person_rounded, 'Profile'),
          ]
        : const [
            (Icons.home_filled, 'Home'),
            (Icons.bar_chart_rounded, 'Insights'),
            (Icons.description_rounded, 'Add Log'),
            (Icons.person_rounded, 'Profile'),
          ];

    return Container(
      height: 95,
      padding: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 20,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(items.length, (i) {
          final (icon, label) = items[i];
          final selected = i == currentIndex;

          // Use purple accent for pregnancy-specific tabs
          final isPregnancyTab = lifeStage == 'pregnant' && (i == 1 || i == 2);
          final activeColor = isPregnancyTab
              ? const Color(0xFF7B2D8E)
              : const Color(0xFF4A6B8D);
          final activeBg = isPregnancyTab
              ? const Color(0xFFF3E5F5)
              : const Color(0xFFE8F0FB);

          return GestureDetector(
            onTap: () => onTap(i),
            behavior: HitTestBehavior.opaque,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: selected ? activeBg : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    icon,
                    size: 26,
                    color: selected ? activeColor : const Color(0xFFB0C4D4),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? activeColor : const Color(0xFFB0C4D4),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}
