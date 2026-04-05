import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentTab = 0;
  String _userName = '';
  String _conditionLabel = 'General Tracking';
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

      final email = user.email ?? '';
      print('Home: Fetching doc for email: $email');

      // Add a timeout to Firestore get just in case
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(email)
          .get()
          .timeout(const Duration(seconds: 5));

      if (doc.exists && mounted) {
        final data = doc.data()!;
        print('Home: Doc exists, data: $data');
        setState(() {
          final name = data['name'] as String? ?? '';
          if (name.isNotEmpty) {
            _userName = name.split(' ').first;
          }
          final stage = data['lifeStage'] as String? ?? 'none';
          _conditionLabel = _conditionTags[stage] ?? 'General Tracking';
        });
      } else {
        print('Home: Doc does not exist for $email');
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
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      body: SafeArea(
        child: _loadingUser
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  const SizedBox(height: 18),

                  // ── Top bar ──────────────────────────────────────────
                  Row(
                    children: [
                      // Avatar
                      Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          color: Color(0xFFDDE8F5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.person,
                          color: Color(0xFF2E4A6B),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Serene Cycle',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2E4A6B),
                        ),
                      ),
                      const Spacer(),
                      // Bell
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.notifications_outlined,
                          color: Color(0xFF2E4A6B),
                          size: 20,
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
                          value: '142 lbs',
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
                      ),
                      _quickAction(
                        icon: Icons.add_reaction_outlined,
                        label: 'Add\nSymptoms',
                        color: const Color(0xFF3A6EA8),
                        bgColor: const Color(0xFFE8F0FB),
                      ),
                      _quickAction(
                        icon: Icons.upload_file_outlined,
                        label: 'Upload\nReport',
                        color: const Color(0xFF2E7D6B),
                        bgColor: const Color(0xFFE0F4F0),
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
      ),
      bottomNavigationBar: _buildBottomNav(),
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
  }) {
    return Column(
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

  // ── Bottom nav ───────────────────────────────────────────────────────
  Widget _buildBottomNav() {
    const items = [
      (Icons.home_rounded, 'Home'),
      (Icons.bar_chart_rounded, 'Insights'),
      (Icons.add_circle_outline, 'Log'),
      (Icons.person_outline, 'Profile'),
    ];

    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(items.length, (i) {
          final (icon, label) = items[i];
          final selected = i == _currentTab;
          return GestureDetector(
            onTap: () => setState(() => _currentTab = i),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 26,
                    color: selected
                        ? const Color(0xFF2E4A6B)
                        : const Color(0xFFB0C4D4),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w400,
                      color: selected
                          ? const Color(0xFF2E4A6B)
                          : const Color(0xFFB0C4D4),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
