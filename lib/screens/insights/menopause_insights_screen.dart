import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/ai_service.dart';

class MenopauseInsightsScreen extends StatefulWidget {
  const MenopauseInsightsScreen({super.key});

  @override
  State<MenopauseInsightsScreen> createState() => _MenopauseInsightsScreenState();
}

class _MenopauseInsightsScreenState extends State<MenopauseInsightsScreen> {
  bool _isLoadingAi = false;
  Map<String, dynamic>? _aiInsightJson;
  Map<String, dynamic> _lastLog = {};

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
        });
        _generateInsight();
      }
    } catch (e) {
      print("Error fetching last log for insights: $e");
    }
  }

  Future<void> _generateInsight({bool force = false}) async {
    final lastLogTimestamp = _lastLog['timestamp']?.seconds ?? 0;
    if (lastLogTimestamp == 0) return;

    final prefs = await SharedPreferences.getInstance();
    final cachedJson = prefs.getString('menopauseAiInsight');
    final cachedTimestamp = prefs.getInt('menopauseAiTimestamp');

    if (!force && cachedJson != null && cachedTimestamp == lastLogTimestamp) {
      if (mounted) setState(() => _aiInsightJson = jsonDecode(cachedJson));
      return;
    }

    setState(() => _isLoadingAi = true);
    try {
      String contextStr = await AiService.getGroundingContext();
      String prompt = """You are a clinical menopause specialist. Analyze the patient logs. Return your analysis STRICTLY as a JSON object strictly following this schema without any markdown formatting wrappers. DO NOT include any dietary or food recommendations, as the user has a separate dedicated AI diet planner. Focus entirely on lifestyle, symptoms, and medical recommendations.
{
  "riskLabel": "Mild Severity",
  "riskPercentage": 30,
  "riskDescription": "A short 1-sentence description based on their symptoms",
  "consultDoctor": true,
  "doctorReason": "Explain why they need to see a doctor if applicable (e.g. rapid symptom escalation)",
  "keyInsight1": "Short 3-4 word phrase (e.g. Sleep quality poor)",
  "keyInsight1Desc": "Short 1-sentence description of the first insight",
  "keyInsight2": "Short 3-4 word phrase (e.g. Frequent hot flashes)",
  "keyInsight2Desc": "Short 1-sentence description of the second insight",
  "trendSummary": "A 2-sentence summary of their overall trends",
  "recommendations": ["A clear action to take", "Another action", "Dose tracking tip"]
}
Logs: $contextStr""";
      
      String? result = await AiService.sendMessage(messages: [{"role": "user", "content": prompt}]);
      
      if (mounted && result != null) {
         result = result.replaceAll('```json', '').replaceAll('```', '').trim();
         final parsed = jsonDecode(result);
         
         await prefs.setString('menopauseAiInsight', jsonEncode(parsed));
         await prefs.setInt('menopauseAiTimestamp', lastLogTimestamp);

         setState(() => _aiInsightJson = parsed);
      }
    } catch(e) {
      if (mounted) setState(() => _aiInsightJson = {"error": true});
    } finally {
      if (mounted) setState(() => _isLoadingAi = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Menopause Insights'),
        actions: [
          IconButton(
            icon: _isLoadingAi 
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) 
                : Icon(Icons.refresh_rounded, color: Theme.of(context).colorScheme.secondary),
            onPressed: _isLoadingAi ? null : () => _generateInsight(force: true),
          )
        ],
      ),
      body: _isLoadingAi && _aiInsightJson == null
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF3A6EA8)))
          : _aiInsightJson == null
              ? const Center(child: Text("Ensure you have submitted logs to see your insights.", style: TextStyle(color: Color(0xFF7A8FA6))))
              : _aiInsightJson!['error'] == true
                  ? const Center(child: Text("Error generating insights.", style: TextStyle(color: Color(0xFFB5616A))))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      child: _buildAiInsightUI(),
                    ),
    );
  }

  Widget _buildAiInsightUI() {
    final ai = _aiInsightJson!;
    final Color riskColor = const Color(0xFFE59A2F);
    final bool needsDoctor = ai['consultDoctor'] ?? false;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Medical Warning (If relevant)
        if (needsDoctor) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: const Color(0xFFFFECEC),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFB5616A).withOpacity(0.3), width: 1.5),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: Color(0xFFB5616A),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.medical_services_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'CONSULT A DOCTOR',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFB5616A),
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        ai['doctorReason'] ?? 'AI analysis suggests speaking with a medical professional regarding your current symptoms.',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF1A2B3C),
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],

        // AI Assessment Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Theme.of(context).colorScheme.secondary, Theme.of(context).primaryColor],
            ),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.25),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                'AI MENOPAUSE ASSESSMENT',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                ai['riskLabel'] ?? 'Assessing...',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: riskColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${ai['riskPercentage'] ?? 0}% severity  •  AI model',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: riskColor,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                ai['riskDescription'] ?? '',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withOpacity(0.8),
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),
        Text(
          'Key Insights',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _insightSquareCard(Icons.warning_amber_rounded, const Color(0xFFE59A2F), ai['keyInsight1'] ?? 'Data logging needed', ai['keyInsight1Desc'] ?? '')),
            const SizedBox(width: 12),
            Expanded(child: _insightSquareCard(Icons.psychology_outlined, const Color(0xFF3A6EA8), ai['keyInsight2'] ?? 'Data tracking stable', ai['keyInsight2Desc'] ?? '')),
          ],
        ),
        
        const SizedBox(height: 24),
        const Text(
          'Trend Summary',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1A2B3C)),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            ai['trendSummary'] ?? '',
            style: const TextStyle(fontSize: 14, color: Color(0xFF7A8FA6), height: 1.6),
          ),
        ),

        const SizedBox(height: 24),
        const Text(
          'Recommendations',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1A2B3C)),
        ),
        const SizedBox(height: 12),
        if (ai['recommendations'] != null)
          ...List.generate(
            (ai['recommendations'] as List).length,
            (index) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF2E7D6B), size: 22),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      ai['recommendations'][index].toString().replaceAll(RegExp(r'^\d+\.\s*'), ''),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1A2B3C)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _insightSquareCard(IconData icon, Color color, String label, String desc) {
    return Container(
      height: 160,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1A2B3C), height: 1.2), maxLines: 2),
          const SizedBox(height: 6),
          Expanded(child: Text(desc, style: const TextStyle(fontSize: 11, color: Color(0xFF7A8FA6), height: 1.3), overflow: TextOverflow.ellipsis, maxLines: 3)),
        ],
      ),
    );
  }
}
