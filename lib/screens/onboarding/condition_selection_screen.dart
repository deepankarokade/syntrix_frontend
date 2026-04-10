import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../home/home_screen.dart';

class ConditionSelectionScreen extends StatefulWidget {
  const ConditionSelectionScreen({super.key});

  @override
  State<ConditionSelectionScreen> createState() =>
      _ConditionSelectionScreenState();
}

class _ConditionSelectionScreenState extends State<ConditionSelectionScreen> {
  // Possible values: 'pcos', 'pregnant', 'menopause', 'none'
  String _selectedCondition = 'none';
  String _selectedTrimester = '1st Trimester (Weeks 1–12)';
  final _weekController = TextEditingController(text: '12'); // Default week
  final _descriptionController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentCondition();
  }

  Future<void> _loadCurrentCondition() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists && mounted) {
        final data = doc.data()!;
        setState(() {
          _selectedCondition = data['lifeStage'] ?? 'none';
          if (data['personalDescription'] != null) {
            _descriptionController.text = data['personalDescription'];
          }
          if (_selectedCondition == 'pregnant' && data['pregnancyWeek'] != null) {
            _weekController.text = data['pregnancyWeek'].toString();
          }
        });
      }
    } catch (e) {
      print("Error loading current condition: $e");
    }
  }

  final List<_ConditionOption> _options = [
    _ConditionOption(
      value: 'pcos',
      label: 'PCOS / PCOD',
      subtitle: null,
      iconData: Icons.monitor_heart_outlined,
      iconBg: Color(0xFFDDE8F5),
      iconColor: Color(0xFF2E4A6B),
    ),
    _ConditionOption(
      value: 'pregnant',
      label: 'Pregnancy',
      subtitle: null,
      iconData: Icons.child_friendly_outlined,
      iconBg: Color(0xFFDDE8F5),
      iconColor: Color(0xFF2E4A6B),
    ),
    _ConditionOption(
      value: 'menopause',
      label: 'Menopause',
      subtitle: null,
      iconData: Icons.wb_sunny_outlined,
      iconBg: Color(0xFFDDE8F5),
      iconColor: Color(0xFF2E4A6B),
    ),
    _ConditionOption(
      value: 'none',
      label: 'No known condition',
      subtitle: 'General Tracking',
      iconData: Icons.track_changes_outlined,
      iconBg: Color(0xFFDDE8F5),
      iconColor: Color(0xFF2E4A6B),
    ),
  ];

  Future<void> _saveCondition() async {
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final Map<String, dynamic> data = {
        'lifeStage': _selectedCondition,
        'personalDescription': _descriptionController.text.trim(),
        'onboardingCompleted': true,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (_selectedCondition == 'pregnant') {
        final week = int.tryParse(_weekController.text) ?? 1;
        String trimesterStr = '1st Trimester (Weeks 1–12)';
        if (week >= 13 && week <= 26) {
          trimesterStr = '2nd Trimester (Weeks 13–26)';
        } else if (week >= 27) {
          trimesterStr = '3rd Trimester (Weeks 27–40)';
        }
        _selectedTrimester = trimesterStr;
        data['trimester'] = trimesterStr;
        data['pregnancyWeek'] = week;
      }

      print('Saving condition for UID: ${user.uid} (Background)');

      // Trigger background update
      FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(data, SetOptions(merge: true))
          .then((_) => print('Condition: Background save finished'))
          .catchError((e) => print('Condition: Background error: $e'));

      // Save to local storage for quick access on restart
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_condition', _selectedCondition);
      if (_selectedCondition == 'pregnant') {
        await prefs.setString('selectedTrimester', _selectedTrimester);
        await prefs.setInt('pregnancyWeek', int.tryParse(_weekController.text) ?? 1);
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving data: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ── Gradient background ────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFEAEFF4),
                  Color(0xFFD6E4EC),
                  Color(0xFFC8D8E5),
                ],
              ),
            ),
          ),

          // ── Soft pink orb (lower portion) ──────────────────────────
          Positioned(
            bottom: -80,
            left: -40,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFFFB5C2).withValues(alpha: 0.35),
                    const Color(0xFFFFB5C2).withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),

          // ── Content ────────────────────────────────────────────────
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Top bar: back arrow + progress dots ─────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.7),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_back,
                            color: Color(0xFF2E4A6B),
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // ── App Title ───────────────────────────────────────
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 28),
                  child: Text(
                    'Serene',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFB5616A),
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // ── Title ────────────────────────────────────────────
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 28),
                  child: Text(
                    'Select Your Condition',
                    textAlign: TextAlign.left,
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A2B3C),
                      height: 1.15,
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 28),
                  child: Text(
                    'This helps us personalize your experience',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Color(0xFF7A8FA6)),
                  ),
                ),

                const SizedBox(height: 28),

                // ── Option cards ─────────────────────────────────────
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        ..._options.map((opt) => _buildOptionCard(opt)),

                        // Pregnancy Week Input (replacing Trimester picker)
                        if (_selectedCondition == 'pregnant') ...[
                          const SizedBox(height: 12),
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Which week of pregnancy are you in?',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1A2B3C),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF2E4A6B,
                                  ).withValues(alpha: 0.06),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: TextField(
                              controller: _weekController,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF1A2B3C),
                              ),
                              decoration: const InputDecoration(
                                hintText: 'Enter week (1–40)',
                                suffixText: 'Week',
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 20),

                        // ── Optional Description ─────────────────────
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Tell us more about you (Optional)',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1A2B3C),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF2E4A6B,
                                ).withValues(alpha: 0.06),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _descriptionController,
                            maxLines: 4,
                            maxLength: 250,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF1A2B3C),
                            ),
                            decoration: InputDecoration(
                              hintText:
                                  'e.g., Any specific symptoms, medical history, or goals...',
                              hintStyle: const TextStyle(
                                color: Color(0xFFB0BEC5),
                              ),
                              contentPadding: const EdgeInsets.all(20),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // ── Privacy notice ───────────────────────────
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.lock_outline,
                                color: Color(0xFF2E4A6B),
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  'Your health data is encrypted and private. We use this only to adjust your tracking algorithms.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF7A8FA6),
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),

                // ── Continue button ───────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        gradient: const LinearGradient(
                          colors: [Color(0xFFB5616A), Color(0xFFC47A82)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFFB5616A,
                            ).withValues(alpha: 0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveCondition,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Continue',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Icon(
                                    Icons.arrow_forward,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionCard(_ConditionOption opt) {
    final bool selected = _selectedCondition == opt.value;
    return GestureDetector(
      onTap: () => setState(() => _selectedCondition = opt.value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? const Color(0xFFB5616A) : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: selected
                  ? const Color(0xFFB5616A).withValues(alpha: 0.12)
                  : const Color(0xFF2E4A6B).withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon badge
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: selected ? const Color(0xFFFFE8E8) : opt.iconBg,
                shape: BoxShape.circle,
              ),
              child: Icon(
                opt.iconData,
                color: selected ? const Color(0xFFB5616A) : opt.iconColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            // Label + optional subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    opt.label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? const Color(0xFF1A2B3C)
                          : const Color(0xFF1A2B3C),
                    ),
                  ),
                  if (opt.subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      opt.subtitle!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF7A8FA6),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Radio circle / checkmark
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: selected
                  ? Container(
                      key: const ValueKey('checked'),
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                        color: Color(0xFFB5616A),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 14,
                      ),
                    )
                  : Container(
                      key: const ValueKey('unchecked'),
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFCDD8E3),
                          width: 2,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Simple data class for condition options
class _ConditionOption {
  final String value;
  final String label;
  final String? subtitle;
  final IconData iconData;
  final Color iconBg;
  final Color iconColor;

  const _ConditionOption({
    required this.value,
    required this.label,
    required this.subtitle,
    required this.iconData,
    required this.iconBg,
    required this.iconColor,
  });
}
