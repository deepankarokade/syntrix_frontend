import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'ai_service.dart';
import 'health_data_service.dart';

class HealthInsightService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Generate and save dynamic insights for PCOS/General conditions
  static Future<Map<String, dynamic>?> generateInsights({bool refresh = false}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;

    final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    
    // 1. Try to fetch existing insight for today
    if (!refresh) {
      final existing = await _getSavedInsight(uid, dateStr);
      if (existing != null) return existing;
    }

    // 2. Build AI prompt with health context
    final healthService = HealthDataService();
    final pcosResult = await healthService.fetchAndPredictRisk();
    final groundingContext = await AiService.getGroundingContext();

    final prompt = """
You are an expert Women's Health Analyst. Analyze the following health data and provide structured clinical insights and recommendations.

## HEALTH DATA CONTEXT:
$groundingContext

## PCOS RISK ASSESSMENT:
- Risk Score: ${pcosResult?.riskPercentage ?? 0}%
- Category: ${pcosResult?.category?.toString().split('.').last ?? 'Unknown'}
- Top Factors: ${pcosResult?.topFeatures.map((f) => "${f.key}: ${f.value.toStringAsFixed(2)}").join(', ') ?? 'None'}

## TASK:
Respond ONLY with a JSON object in the following format (NO MARKDOWN outside JSON):
{
  "summary": "A 2-3 sentence overview of her health status today.",
  "recommendations": [
    {"label": "Recommendation text (short)", "icon": "flutter_icon_name", "type": "activity|diet|medical"},
    ... (max 3)
  ],
  "suggestedContent": [
    {
      "category": "EXERCISE|NUTRITION|WELLNESS",
      "title": "Interesting title",
      "imageUrl": "Unsplash URL related to topic"
    },
    ... (max 2)
  ],
  "lifestyleAlert": "Short alert title",
  "lifestyleMessage": "Actionable secondary message"
}

Icons to use for recommendations: directions_run, restaurant, self_improvement, water_drop, medkit, sleep.
Ensure the suggestions are tailored. If high PCOS risk, suggest low glycemic nutrition. If stressed, suggest yoga.
""";

    try {
      final response = await AiService.sendMessage(
        messages: [
          {"role": "user", "content": prompt},
        ],
      );

      if (response == null || response.contains('Error:')) return null;

      // Clean JSON if AI added markdown backticks
      String cleanJson = response.trim();
      if (cleanJson.startsWith('```json')) {
        cleanJson = cleanJson.substring(7, cleanJson.length - 3).trim();
      } else if (cleanJson.startsWith('```')) {
        cleanJson = cleanJson.substring(3, cleanJson.length - 3).trim();
      }

      final data = jsonDecode(cleanJson) as Map<String, dynamic>;
      
      // Save to Firestore
      await _saveInsight(uid, dateStr, data);
      
      return data;
    } catch (e) {
      print('HealthInsightService Error: $e');
      return null;
    }
  }

  static Future<void> _saveInsight(String uid, String dateStr, Map<String, dynamic> data) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('ai_insights')
        .doc(dateStr)
        .set({
      ...data,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  static Future<Map<String, dynamic>?> _getSavedInsight(String uid, String dateStr) async {
    final doc = await _db
        .collection('users')
        .doc(uid)
        .collection('ai_insights')
        .doc(dateStr)
        .get();
    return doc.exists ? doc.data() : null;
  }
}
