import 'package:flutter/material.dart';
import '../../services/health_data_service.dart';
import '../../services/pcos_predictor.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  final HealthDataService _service = HealthDataService();
  PcosResult? _result;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPrediction();
  }

  Future<void> _loadPrediction() async {
    setState(() { _loading = true; _error = null; });
    try {
      final result = await _service.fetchAndPredictRisk();
      setState(() { _result = result; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  // ── Risk category styling helpers ─────────────────────────────────────────
  Color _riskColor(RiskCategory? cat) {
    switch (cat) {
      case RiskCategory.low:      return const Color(0xFF2E7D6B);
      case RiskCategory.moderate: return const Color(0xFFE59A2F);
      case RiskCategory.high:     return const Color(0xFFB5616A);
      default:                    return const Color(0xFF3A6EA8);
    }
  }

  String _riskLabel(RiskCategory? cat) {
    switch (cat) {
      case RiskCategory.low:      return 'Low Risk';
      case RiskCategory.moderate: return 'Moderate Risk';
      case RiskCategory.high:     return 'High Risk';
      default:                    return 'Assessing...';
    }
  }

  String _riskDescription(RiskCategory? cat) {
    switch (cat) {
      case RiskCategory.low:
        return 'Your hormonal trends look stable and healthy. Keep up your current lifestyle habits.';
      case RiskCategory.moderate:
        return 'Some PCOS risk indicators are present. Consider speaking with your healthcare provider.';
      case RiskCategory.high:
        return 'Several PCOS risk factors have been detected. Please consult your doctor soon.';
      default:
        return 'Analysing your health data...';
    }
  }

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
        actions: [
          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF2E4A6B)),
            onPressed: _loadPrediction,
            tooltip: 'Refresh assessment',
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Color(0xFF3A6EA8)),
                  SizedBox(height: 16),
                  Text(
                    'Analysing your health data...',
                    style: TextStyle(color: Color(0xFF7A8FA6), fontSize: 14),
                  ),
                ],
              ),
            )
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, color: Color(0xFFB5616A), size: 48),
                        const SizedBox(height: 12),
                        const Text('Could not load insights',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        TextButton(onPressed: _loadPrediction, child: const Text('Try again')),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadPrediction,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 10),

                        // ── Health Assessment Card ───────────────────────
                        _buildAssessmentCard(),

                        const SizedBox(height: 32),

                        // ── Key Insights ─────────────────────────────────
                        const Text(
                          'Key Insights',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1A2B3C),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildInsightAlert(),
                        const SizedBox(height: 12),
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

                        // ── Top Contributing Features ────────────────────
                        if (_result != null && _result!.topFeatures.isNotEmpty) ...[
                          const Text(
                            'Top Contributing Factors',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1A2B3C),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildTopFeatures(),
                          const SizedBox(height: 32),
                        ],

                        // ── Trend Summary ────────────────────────────────
                        const Text(
                          'Trend Summary',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1A2B3C),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildTrendSummary(),

                        const SizedBox(height: 32),

                        // ── Recommendations ──────────────────────────────
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

                        // ── Suggested for You ────────────────────────────
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
                          height: 220,
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
                ),
    );
  }

  // ── Health Assessment Card ─────────────────────────────────────────────────
  Widget _buildAssessmentCard() {
    final cat   = _result?.category;
    final color = _riskColor(cat);
    final pct   = _result?.riskPercentage ?? 0;
    final model = _result?.modelUsed ?? '-';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFDDE8F5).withOpacity(0.8),
            const Color(0xFFE8EDF4).withOpacity(0.6),
          ],
        ),
        border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2E4A6B).withOpacity(0.05),
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
              color: const Color(0xFF2E4A6B).withOpacity(0.5),
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _riskLabel(cat),
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          // Risk percentage pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$pct% risk score  •  ${model.toUpperCase()} model',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _riskDescription(cat),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF7A8FA6),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ── Alert card based on risk level ────────────────────────────────────────
  Widget _buildInsightAlert() {
    final cat = _result?.category ?? RiskCategory.low;
    final isHighRisk = cat == RiskCategory.high || cat == RiskCategory.moderate;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
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
            decoration: BoxDecoration(
              color: isHighRisk
                  ? const Color(0xFFFFF0F0)
                  : const Color(0xFFE8F5E9),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isHighRisk
                  ? Icons.warning_amber_rounded
                  : Icons.check_circle_outline_rounded,
              color: isHighRisk
                  ? const Color(0xFFB5616A)
                  : const Color(0xFF2E7D6B),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isHighRisk
                      ? 'Irregular cycle pattern detected'
                      : 'Cycle pattern looks stable',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A2B3C),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isHighRisk
                      ? 'Multiple risk factors detected in your recent data.'
                      : 'Your recent health logs show a healthy trend.',
                  style: const TextStyle(
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
    );
  }

  // ── Top Features bar chart ─────────────────────────────────────────────────
  Widget _buildTopFeatures() {
    final features = _result!.topFeatures;
    final maxVal = features.isNotEmpty ? features.first.value : 1.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: features.map((entry) {
          final ratio = maxVal > 0 ? (entry.value / maxVal).clamp(0.0, 1.0) : 0.0;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    entry.key,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF7A8FA6),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 4,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: ratio,
                      minHeight: 8,
                      backgroundColor: const Color(0xFFE8EDF4),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF3A6EA8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Trend Summary ──────────────────────────────────────────────────────────
  Widget _buildTrendSummary() {
    final pct   = _result?.riskPercentage ?? 0;
    final model = _result?.modelUsed ?? 'basic';
    final topFeature = _result?.topFeatures.isNotEmpty == true
        ? _result!.topFeatures.first.key
        : 'BMI';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white, width: 1),
      ),
      child: Text.rich(
        TextSpan(
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF7A8FA6),
            height: 1.6,
          ),
          children: [
            const TextSpan(text: 'Based on your recent health logs, the '),
            TextSpan(
              text: '${model.toUpperCase()} model',
              style: const TextStyle(
                color: Color(0xFF3A6EA8),
                fontWeight: FontWeight.w600,
              ),
            ),
            TextSpan(text: ' assessed your PCOS risk at '),
            TextSpan(
              text: '$pct%',
              style: const TextStyle(
                color: Color(0xFF3A6EA8),
                fontWeight: FontWeight.w600,
              ),
            ),
            const TextSpan(
              text: '.\n\nThe most influential factor in this assessment was ',
            ),
            TextSpan(
              text: topFeature,
              style: const TextStyle(
                color: Color(0xFF3A6EA8),
                fontWeight: FontWeight.w600,
              ),
            ),
            const TextSpan(
              text: '. Your next phase will be updated as more health data is logged.',
            ),
          ],
        ),
      ),
    );
  }

  // ── Small secondary insight card ───────────────────────────────────────────
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
            color: Colors.black.withOpacity(0.03),
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

  // ── Recommendation tile ────────────────────────────────────────────────────
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

  // ── Suggested content card ─────────────────────────────────────────────────
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
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
