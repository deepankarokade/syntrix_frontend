import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AiService {
  static String get _apiKey => dotenv.env['OPENROUTER_API_KEY'] ?? '';
  static String get _apiUrl => dotenv.env['OPENROUTER_API_URL'] ?? 'https://openrouter.ai/api/v1/chat/completions';

  static const String chatSystemPrompt = """
You are a HIGH-PRECISION Women's Health AI Assistant.

STRICT RULES:
- NO hallucinations. ONLY respond based on provided user health data and medical facts.
- If data is missing for a specific date, state "No data recorded for [Date]" instead of assuming.
- If the user asks a question NOT related to health and women's well-being, you must politely decline and state that you only answer questions related to health.
- If unsure → say "I cannot verify this medically"
- Always include clinical parameters (TSH, HbA1c, etc.)
- Use evidence-based medicine only
- If needed → explicitly say "Searching medical data..."

DOMAIN:
PCOS, Thyroid, Insulin Resistance, Diabetes, PMS, Amenorrhea, Obesity, Infertility

FORMAT:
- Tables
- Bullet points
- Clinical ranges
- Clear explanation

SAFETY:
- Do NOT give final diagnosis
- Suggest consulting doctor
""";

  static const String dietSystemPrompt = """
You are an ELITE CLINICAL NUTRITION AI for women's health.

MISSION:
Generate highly personalized, medically accurate diet plans based strictly on user data.

STRICT RULES:
- ZERO hallucination. 
- NEVER assume missing values. If weight or height is not in the context, ASK for it.
- If required data is missing → ASK QUESTIONS FIRST.
- Use only medically accepted clinical ranges.
- If unsure → say "I cannot verify this medically"

SUPPORTED CONDITIONS:
PCOS, PCOD, Thyroid (hypo/hyper), Hyperprolactinemia,
Insulin Resistance, Type 2 Diabetes, Metabolic Syndrome,
Infertility, PMS, Amenorrhea, Obesity

MANDATORY DATA:
- Age
- Height (cm)
- Weight (kg)
- Activity level
- Menstrual status
- Diagnosed conditions
- Symptoms
- Lab values if available (HbA1c, glucose, TSH, insulin, prolactin)
- Region/Location (for food availability and local diet preferences)

LOGIC:
1. Validate completeness of data
2. If incomplete → ask structured follow-up questions
3. If disease present → apply condition-specific diet logic
4. If no disease → optimize hormonal and metabolic health

DIET RULES:
- Provide full-day structured diet tailored to their REGIONAL foods
- Include calorie estimation
- Include protein, carbs, fats reasoning
- Avoid harmful foods based on condition

OUTPUT FORMAT:
- Tables
- Bullet points
- Clear medical reasoning
""";

  /// Send query to OpenRouter AI
  static Future<String?> sendMessage({
    required List<Map<String, String>> messages,
    bool isDiet = false,
  }) async {
    try {
      final payload = {
        "model": "google/gemini-2.0-flash-001",
        "messages": messages,
        "temperature": 0.2,
        "max_tokens": 800,
      };

      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          "Authorization": "Bearer $_apiKey",
          "HTTP-Referer": "http://localhost",
          "X-Title": "Women Health AI",
          "Content-Type": "application/json"
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["choices"] != null && data["choices"].isNotEmpty) {
          return data["choices"][0]["message"]["content"];
        }
      }
      return "Error: Unable to fetch response (Status ${response.statusCode})\\n${response.body}";
    } catch (e) {
      return "Error: $e";
    }
  }

  /// Fetches last 7 days of logs + profile to build a grounding context for AI
  static Future<String> getGroundingContext() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return "User not logged in.";

    try {
      final profileDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final profile = profileDoc.data() ?? {};
      
      final logsCol = FirebaseFirestore.instance
          .collection('logs')
          .doc(user.uid)
          .collection('daily_entries');
      
      final now = DateTime.now();
      final last7Days = await logsCol
          .where('timestamp', isGreaterThan: now.subtract(const Duration(days: 7)))
          .orderBy('timestamp', descending: true)
          .get();

      StringBuffer context = StringBuffer();
      context.writeln("USER PROFILE:");
      context.writeln("- Name: ${profile['name'] ?? 'Not provided'}");
      context.writeln("- Age/DOB: ${profile['dob'] ?? 'Not provided'}");
      context.writeln("- Height: ${profile['height'] ?? 'Not provided'} cm");
      context.writeln("- Weight: ${profile['weight'] ?? 'Not provided'} kg");
      context.writeln("- Conditions: ${profile['condition'] ?? 'None'}");
      
      context.writeln("\nRECENT HEALTH LOGS (LAST 7 DAYS):");
      if (last7Days.docs.isEmpty) {
        context.writeln("No logs found for the last 7 days.");
      } else {
        for (var doc in last7Days.docs) {
          final data = doc.data();
          final date = doc.id.split('_').first;
          final time = data['timeOfLog'] ?? 'Unknown';
          context.writeln("Date: $date ($time)");
          context.writeln("  - Status: ${data['isOnPeriod'] == true ? 'On Period (Day ${data['periodDay']})' : 'Not on period'}");
          context.writeln("  - Phase: ${data['periodPhase'] ?? 'N/A'}");
          context.writeln("  - Symptoms: ${data['symptoms'] ?? 'None'}");
          context.writeln("  - Mood: ${data['mood'] ?? 'General'}");
          context.writeln("  - Sleep: ${data['sleep'] ?? 'N/A'}");
          context.writeln("  - Activity: ${data['activity'] ?? 'N/A'}");
          context.writeln("  - Weight: ${data['weight'] ?? 'Same as profile'}");
          if (data['waist'] != null) context.writeln("  - Waist: ${data['waist']} cm, Hip: ${data['hip']} cm");
          if (data['ateFastFood'] != null) context.writeln("  - Fast Food Consumed: ${data['ateFastFood']}");
        }
      }
      
      return context.toString();
    } catch (e) {
      return "Error building AI context: $e";
    }
  }
}
