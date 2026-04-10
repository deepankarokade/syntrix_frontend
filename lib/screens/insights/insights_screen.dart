import 'package:flutter/material.dart';

class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Insights',
          style: TextStyle(
            color: Color(0xFF2E4A6B),
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),

            // ── Health Assessment Card ───────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFFDDE8F5).withValues(alpha: 0.8),
                    const Color(0xFFE8EDF4).withValues(alpha: 0.6),
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.5),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2E4A6B).withValues(alpha: 0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    'HEALTH ASSESSMENT',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF2E4A6B).withValues(alpha: 0.5),
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Risk Level: Low',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF3A6EA8),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Your hormonal trends look stable and healthy.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF7A8FA6),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // ── Key Insights Section ──────────────────────────────────
            const Text(
              'Key Insights',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A2B3C),
              ),
            ),
            const SizedBox(height: 16),

            // Irregular cycle alert card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFF0F0),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      color: Color(0xFFB5616A),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Irregular cycle pattern detected',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1A2B3C),
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Your follicular phase was 3 days longer than usual this month.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF7A8FA6),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Two-column secondary insight cards
            Row(
              children: [
                Expanded(
                  child: _smallInsightCard(
                    icon: Icons.trending_up,
                    iconColor: const Color(0xFF3A6EA8),
                    label: 'Weight trend increasing',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _smallInsightCard(
                    icon: Icons.psychology_outlined,
                    iconColor: const Color(0xFF2E7D6B),
                    label: 'Possible lifestyle impact',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // ── Trend Summary Section ─────────────────────────────────
            const Text(
              'Trend Summary',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A2B3C),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white, width: 1),
              ),
              child: const Text.rich(
                TextSpan(
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF7A8FA6),
                    height: 1.6,
                  ),
                  children: [
                    TextSpan(text: 'Over the last 3 months, your cycle duration has '),
                    TextSpan(
                      text: 'varied slightly',
                      style: TextStyle(
                        color: Color(0xFF3A6EA8),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    TextSpan(text: ', averaging 29 days but with a standard deviation of 4 days.\n\nAnalysis shows your weight has '),
                    TextSpan(
                      text: 'gradually increased',
                      style: TextStyle(
                        color: Color(0xFF3A6EA8),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    TextSpan(text: ' by 1.8kg. This correlates with reported lower sleep quality during your luteal phase.'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // ── Recommendations Section ───────────────────────────────
            const Text(
              'Recommendations',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A2B3C),
              ),
            ),
            const SizedBox(height: 16),
            _recommendationTile(
              icon: Icons.directions_run_rounded,
              iconColor: const Color(0xFF3A6EA8),
              label: 'Increase daily activity',
            ),
            _recommendationTile(
              icon: Icons.restaurant_rounded,
              iconColor: const Color(0xFFB5616A),
              label: 'Maintain balanced diet',
            ),
            _recommendationTile(
              icon: Icons.calendar_today_rounded,
              iconColor: const Color(0xFF2E7D6B),
              label: 'Track symptoms regularly',
            ),

            const SizedBox(height: 32),

            // ── Suggested for You Section ─────────────────────────────
            const Text(
              'Suggested for You',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A2B3C),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 220, // increased height for larger cards
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _suggestedContentCard(
                    category: 'EXERCISE',
                    title: 'Low-impact Yoga for Follicular Phase',
                    imageUrl: 'https://images.unsplash.com/photo-1544367567-0f2fcb009e0b?q=80&w=600&auto=format&fit=crop',
                  ),
                  _suggestedContentCard(
                    category: 'NUTRITION',
                    title: 'Magnesium-Rich Recipes for Balance',
                    imageUrl: 'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?q=80&w=600&auto=format&fit=crop',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ── Small secondary insight card ────────────────────────────────
  Widget _smallInsightCard({
    required IconData icon,
    required Color iconColor,
    required String label,
  }) {
    return Container(
      height: 120,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: iconColor, size: 24),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A2B3C),
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  // ── Recommendation list item ──────────────────────────────────────
  Widget _recommendationTile({
    required IconData icon,
    required Color iconColor,
    required String label,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(width: 14),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A2B3C),
            ),
          ),
        ],
      ),
    );
  }

  // ── Suggested Content Card ───────────────────────────────────────
  Widget _suggestedContentCard({
    required String category,
    required String title,
    required String imageUrl,
  }) {
    return Container(
      width: 220,
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image portion
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: Image.network(
              imageUrl,
              height: 120,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                height: 120,
                color: const Color(0xFFE8EDF4),
                child: const Icon(Icons.image, color: Colors.white, size: 30),
              ),
            ),
          ),
          // Text portion
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF3A6EA8),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A2B3C),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
