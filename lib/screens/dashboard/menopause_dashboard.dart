import 'package:flutter/material.dart';
import '../onboarding/condition_selection_screen.dart';

class MenopauseDashboard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wb_sunny_outlined, size: 80, color: Color(0xFF2E4A6B)),
          const SizedBox(height: 20),
          Text(
            'Welcome, $userName',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A2B3C),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Menopause Support Module',
            style: TextStyle(fontSize: 18, color: Color(0xFF7A8FA6)),
          ),
          const SizedBox(height: 20),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'We are currently building specialized insights for menopause. Stay tuned!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF7A8FA6)),
            ),
          ),
          const SizedBox(height: 40),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const ConditionSelectionScreen()),
              );
            },
            icon: const Icon(Icons.swap_horiz),
            label: const Text('Switch Condition'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFB5616A),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
