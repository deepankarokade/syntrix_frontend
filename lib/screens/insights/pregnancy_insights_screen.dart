import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/ai_service.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class PregnancyInsightsScreen extends StatefulWidget {
  final int pregnancyWeek;
  const PregnancyInsightsScreen({super.key, this.pregnancyWeek = 24});

  @override
  State<PregnancyInsightsScreen> createState() => _PregnancyInsightsScreenState();
}

class _PregnancyInsightsScreenState extends State<PregnancyInsightsScreen> {
  int _currentWeek = 24;
  String? _aiInsight;
  bool _isLoadingAi = false;

  @override
  void initState() {
    super.initState();
    _currentWeek = widget.pregnancyWeek;
    _loadTrimester();
  }

  Future<void> _loadTrimester() async {
    final prefs = await SharedPreferences.getInstance();
    int? savedWeek = prefs.getInt("pregnancyWeek");
    if (mounted) {
      setState(() {
        if (savedWeek != null) _currentWeek = savedWeek;
      });
    }
  }

  Future<void> _fetchAiInsights() async {
    setState(() => _isLoadingAi = true);
    try {
      String contextStr = await AiService.getGroundingContext();
      String prompt = "You are a clinical AI for pregnancy tracking. The user is currently at week $_currentWeek. Calculate the approximate remaining weeks until the exact due date. Suggest 3 concrete recommendations specifically based on any clinical anomalies in these logs:\n\n$contextStr\n\nReturn the response formatted strictly as clean Markdown.";
      
      String? result = await AiService.sendMessage(messages: [{"role": "user", "content": prompt}]);
      if (mounted && result != null) {
         setState(() => _aiInsight = result);
      }
    } catch(e) {
      if (mounted) setState(() => _aiInsight = "Failed to load clinical AI pregnancy analysis.");
    } finally {
      if (mounted) setState(() => _isLoadingAi = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Dummy data for logic
    const double bloodSugar = 124.0;
    const int steps = 4280;
    const double weightGain = 0.2; // kg this week

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF2E4A6B)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Pregnancy Insights',
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

            // ── Gestational Assessment Card ──────────────────────────
            _buildAssessmentCard(),

            const SizedBox(height: 32),

            // ── Smart AI Insights Section ────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Smart AI Insights',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A2B3C),
                  ),
                ),
                TextButton.icon(
                  onPressed: _isLoadingAi ? null : _fetchAiInsights,
                  icon: _isLoadingAi 
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.auto_awesome, size: 18, color: Color(0xFF3A6EA8)),
                  label: Text(_isLoadingAi ? 'Loading...' : 'Generate AI Insights', style: const TextStyle(color: Color(0xFF3A6EA8))),
                )
              ],
            ),
            const SizedBox(height: 16),

            if (_aiInsight == null && !_isLoadingAi)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange),
                    SizedBox(width: 10),
                    Expanded(child: Text("Push the Generate button to analyze your clinical logs and calculate precise due date insights.", style: TextStyle(color: Colors.orange))),
                  ],
                ),
              ),

             if (_aiInsight != null)
               Container(
                 padding: const EdgeInsets.all(20),
                 decoration: BoxDecoration(
                   color: Colors.white,
                   borderRadius: BorderRadius.circular(20),
                   border: Border.all(color: const Color(0xFF3A6EA8).withValues(alpha: 0.2)),
                   boxShadow: [
                     BoxShadow(
                       color: Colors.black.withValues(alpha: 0.04),
                       blurRadius: 14,
                       offset: const Offset(0, 6),
                     ),
                   ],
                 ),
                 child: MarkdownBody(
                   data: _aiInsight!,
                   styleSheet: MarkdownStyleSheet(
                     p: const TextStyle(fontSize: 14, color: Color(0xFF1A2B3C), height: 1.5),
                     h1: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2E4A6B)),
                     h2: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF3A6EA8)),
                   ),
                 ),
               ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildAssessmentCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF3A6EA8).withValues(alpha: 0.9),
            const Color(0xFF2E4A6B).withValues(alpha: 0.9),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3A6EA8).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'GESTATIONAL HEALTH OVERVIEW',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.6),
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _getWeekStatus(),
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Keep monitoring your blood sugar consistently to maintain optimal vitality.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.white70,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  String _getWeekStatus() {
    int week = _currentWeek;
    String status = "Early Pregnancy";
    if (week >= 13 && week <= 26) {
      status = "Growth Phase";
    } else if (week >= 27) {
      status = "Final Stage";
    }
    return "Week $week • $status";
  }

  Widget _buildInsightCard({
    required String title,
    required String desc,
    required String status,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A2B3C),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: iconColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
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

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: Color(0xFF1A2B3C),
      ),
    );
  }

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
}
