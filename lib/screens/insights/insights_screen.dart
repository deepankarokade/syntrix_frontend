import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/health_data_service.dart';
import '../../services/pcos_predictor.dart';
import '../../services/health_insight_service.dart';
import '../../widgets/health_metrics_chart.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  final HealthDataService _service = HealthDataService();
  Map<String, dynamic>? _aiInsights;
  bool _loadingAi = true;

  bool _loading = true;
  String? _error;
  PcosResult? _result;

  List<HealthMetricPoint> _historicalMetrics = [];
  bool _loadingMetrics = true;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    await Future.wait([
      _loadPrediction(),
      _loadAiInsights(),
      _loadHistory(),
    ]);
  }

  Future<void> _loadHistory() async {
    setState(() => _loadingMetrics = true);
    final metrics = await _service.fetchHistoricalMetrics(days: 30);
    if (mounted) {
      setState(() {
        _historicalMetrics = metrics;
        // Sort by date ascending for the chart
        _historicalMetrics.sort((a, b) => a.date.compareTo(b.date));
        _loadingMetrics = false;
      });
    }
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

  Future<void> _loadAiInsights({bool refresh = false}) async {
    setState(() => _loadingAi = true);
    final insights = await HealthInsightService.generateInsights(refresh: refresh);
    if (mounted) {
      setState(() {
        _aiInsights = insights;
        _loadingAi = false;
      });
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Insights'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => _loadAllData(),
            tooltip: 'Refresh assessment',
          ),
        ],
      ),
      body: _loading
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Theme.of(context).primaryColor),
                  const SizedBox(height: 16),
                  Text(
                    'Analysing your health data...',
                    style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color, fontSize: 14),
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
                  onRefresh: _loadAllData,
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
                        Text(
                          'Key Insights',
                          style: Theme.of(context).textTheme.titleLarge,
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

                        // ── Historical Health Graph ──────────────────────
                        const Text(
                          'Historical Health Metrics',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1A2B3C),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const HealthMetricsChart(),

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
                        if (_loadingAi)
                          const Center(child: Padding(
                            padding: EdgeInsets.all(20.0),
                            child: CircularProgressIndicator(),
                          ))
                        else if (_aiInsights != null && _aiInsights!['recommendations'] != null)
                          ...( _aiInsights!['recommendations'] as List).map((rec) => _recommendationTile(
                            icon: _getIconData(rec['icon']),
                            iconColor: const Color(0xFF3A6EA8),
                            label: rec['label'],
                          ))
                        else
                          const Text('Record more logs to see personalized recommendations.'),

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
                        if (_loadingAi)
                           const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()))
                        else if (_aiInsights != null && _aiInsights!['suggestedContent'] != null)
                          SizedBox(
                            height: 220,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              children: (_aiInsights!['suggestedContent'] as List).map((item) => _suggestedContentCard(
                                category: item['category'],
                                title: item['title'],
                                imageUrl: item['imageUrl'],
                              )).toList(),
                            ),
                          )
                        else
                          const Text('Check back soon for tailored wellness tips.'),

                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
    );
  }

  IconData _getIconData(String? name) {
    switch (name) {
      case 'directions_run': return Icons.directions_run_rounded;
      case 'restaurant': return Icons.restaurant_rounded;
      case 'self_improvement': return Icons.self_improvement_rounded;
      case 'water_drop': return Icons.water_drop_rounded;
      case 'medkit': return Icons.medical_services_rounded;
      case 'sleep': return Icons.bedtime_rounded;
      default: return Icons.check_circle_rounded;
    }
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
          colors: [Theme.of(context).colorScheme.secondary, Theme.of(context).primaryColor],
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
              color: Colors.white70,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _riskLabel(cat),
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Colors.white,
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
