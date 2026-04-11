import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'ai_service.dart';
import 'health_data_service.dart';
import 'pcos_predictor.dart';

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

## PCOS/HEALTH RISK ASSESSMENT (Top 5 Factors):
- Risk Score: ${pcosResult?.riskPercentage ?? 0}%
- Category: ${pcosResult?.category?.toString().split('.').last ?? 'Unknown'}
- Primary Contributors: ${pcosResult?.topFeatures.map((f) => "${f.key} (Intensity: ${f.value.toStringAsFixed(2)})").join(', ') ?? 'None'}

## TASK:
Respond ONLY with a JSON object in the following format (NO MARKDOWN outside JSON):
{
  "summary": "A 2-3 sentence overview of her health status today, specifically mentioning how the top factors are affecting her.",
  "recommendations": [
    {"label": "Detailed Diet Tip", "icon": "restaurant", "type": "diet"},
    {"label": "Core Lifestyle Change", "icon": "directions_run", "type": "lifestyle"},
    {"label": "Clinical/Medical advice", "icon": "medkit", "type": "medical"}
  ],
  "suggestedContent": [
    {
      "category": "EXERCISE|NUTRITION|WELLNESS",
      "title": "Topic related to her top risk factor",
      "description": "2-3 paragraphs of detailed, actionable advice and medical context.",
      "imageUrl": "Unsplash URL related to topic"
    },
    ... (max 2)
  ],
  "lifestyleAlert": "Short alert title based on highest factor",
  "lifestyleMessage": "Specific warning or encouragement"
}

Ensure recommendations explicitly address the 'Top Factors' listed above for PCOS/PCOD or general health maintenance.
Icons: directions_run, restaurant, self_improvement, water_drop, medkit, sleep.
If the 'LATEST CLINICAL REPORT' in Health Data Context contains hormonal markers (LH, FSH, AMH, etc.), YOU MUST explicitly analyze them in the summary and recommendations, even if they aren't the top statistical factors from the model.
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
      
      // 3. Save Insight and raw Factors to Firestore
      await _saveInsight(uid, dateStr, data);
      
      if (pcosResult != null) {
        await _saveFactors(uid, dateStr, pcosResult);
      }
      
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

  /// Save raw PCOS/Health factors for analysis history
  static Future<void> _saveFactors(String uid, String dateStr, PcosResult result) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('health_factors')
        .doc(dateStr)
        .set({
      'riskScore': result.riskScore,
      'riskPercentage': result.riskPercentage,
      'category': result.category.toString().split('.').last,
      'modelUsed': result.modelUsed,
      'topFactors': result.topFeatures.map((e) => {
        'factor': e.key,
        'intensity': e.value,
      }).toList(),
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
