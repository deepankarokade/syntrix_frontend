import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AiService {
  static String get _apiKey => dotenv.env['OPENROUTER_API_KEY'] ?? '';
  static String get _apiUrl =>
      dotenv.env['OPENROUTER_API_URL'] ??
      'https://openrouter.ai/api/v1/chat/completions';

  static String get _groqApiKey => dotenv.env['GROQ_API_KEY'] ?? '';
  static const String _groqApiUrl = 'https://api.groq.com/openai/v1/chat/completions';

  static const String chatSystemPrompt = """
You are a HIGH-PRECISION Women's Health AI Assistant.

LANGUAGE RULES (CRITICAL):
- You MUST detect the language the user is writing in.
- ALWAYS reply in the SAME language the user uses.
- You support: English, Hindi, Marathi, Tamil, Telugu, Kannada, Bengali, Gujarati, Malayalam, Punjabi, Urdu, and any other Indian or global language.
- If the user writes in Marathi (e.g., "PCOS म्हणजे काय?"), respond fully in Marathi.
- If the user writes in Hindi (e.g., "PCOS kya hai?"), respond fully in Hindi.
- If the user mixes languages (Hinglish/Marathlish), respond in the same mixed style.
- Medical terms (like PCOS, TSH, HbA1c) can remain in English even when responding in other languages.

STRICT RULES:
- NO hallucinations. ONLY respond based on provided user health data and medical facts.
- If data is missing for a specific date, state "No data recorded for [Date]" instead of assuming.
- If the user asks a question NOT related to health and women's well-being, you must politely decline and state that you only answer questions related to health.
- If unsure → say "I cannot verify this medically"
- Always include clinical parameters (TSH, HbA1c, etc.)
- Use evidence-based medicine only
- If needed → explicitly say "Searching medical data..."

DOMAIN:
PCOS, Thyroid, Insulin Resistance, Diabetes, PMS, Amenorrhea, Obesity, Infertility, Pregnancy, Menopause

FORMAT:
- Tables
- Bullet points
- Clinical ranges
- Clear explanation in the user's language

SAFETY:
- Do NOT give final diagnosis
- Suggest consulting doctor
""";

  static const String dietSystemPrompt = """
You are an ELITE CLINICAL NUTRITION AI for women's health.

MISSION:
Generate a highly personalized, medically accurate diet plan IMMEDIATELY based on the provided user data.

STRUCTURE YOUR RESPONSE INTO THREE DISTINCT SECTIONS:
1. ## FULL MEAL PLAN
   Provide a complete daily meal schedule (Breakfast, Mid-morning, Lunch, Snack, Dinner).
   Ensure this is specific to today's metabolic needs based on their logs.

2. ## NUTRIENTS FOCUS
   List essential vitamins, minerals, and macronutrients required for their current condition (e.g., Vitamin D, Inositol for PCOS, Iron for Pregnancy).
   Explain WHY these are needed.

3. ## ITEMS TO AVOID & REASONS
   List specific foods or ingredients they should STRICTLY avoid for their condition.
   Provide a clear medical reason for each avoidance (e.g., "Avoid refined sugar because it spikes insulin which worsens PCOS symptoms").

STRICT RULES:
- NEVER ask the user follow-up questions.
- GENERATE the plan immediately in the first response.
- Use only medically accepted clinical ranges.
- Provide tailored advice for their REGIONAL foods if provided.
- Include calorie estimation and protein/carbs/fats reasoning.

OUTPUT FORMAT:
- Beautiful Markdown. DO NOT use Tables (they render poorly on mobile). Use detailed bulleted/numbered lists for the meal plan.
- Clear headers and bold text.
- Professional medical reasoning.
""";

  static const List<String> _freeModels = [
    "google/gemma-4-31b-it:free",
    "openrouter/free"
  ];

  /// Send query to OpenRouter AI with automatic Groq fallback
  static Future<String?> sendMessage({
    required List<Map<String, String>> messages,
    bool isDiet = false,
  }) async {
    for (int i = 0; i < _freeModels.length; i++) {
      try {
        final model = _freeModels[i];
        print(
          "AI: Trying OpenRouter model $model (attempt ${i + 1}/${_freeModels.length})",
        );

        final payload = {
          "model": model,
          "messages": messages,
          "temperature": 0.3,
          "max_tokens": isDiet ? 2000 : 800,
        };

        final response = await http.post(
          Uri.parse(_apiUrl),
          headers: {
            "Authorization": "Bearer $_apiKey",
            "HTTP-Referer": "http://localhost",
            "X-Title": "Women Health AI",
            "Content-Type": "application/json",
          },
          body: jsonEncode(payload),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data["choices"] != null && data["choices"].isNotEmpty) {
            print("AI: Success with $model");
            return data["choices"][0]["message"]["content"];
          }
        }

        print("AI: Failed on $model (Status ${response.statusCode}), trying next...");
      } catch (e) {
        print("AI: Error with OpenRouter model ${_freeModels[i]}: $e");
      }
    }

    if (_groqApiKey.isNotEmpty) {
      print("AI: OpenRouter models failed. Falling back to Groq API...");
      try {
        final payload = {
          "model": "llama-3.1-8b-instant",
          "messages": messages,
          "temperature": 0.3,
          "max_tokens": isDiet ? 2000 : 800,
        };

        final response = await http.post(
          Uri.parse(_groqApiUrl),
          headers: {
            "Authorization": "Bearer $_groqApiKey",
            "Content-Type": "application/json",
          },
          body: jsonEncode(payload),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data["choices"] != null && data["choices"].isNotEmpty) {
            print("AI: Success with Groq fallback.");
            return data["choices"][0]["message"]["content"];
          }
        } else {
          print("AI: Groq failed with status ${response.statusCode}");
        }
      } catch (e) {
        print("AI: Groq fallback Error: $e");
      }
    } else {
      print("AI: No Groq API Key found in .env, skipping fallback.");
    }

    return "Error: All AI endpoints are currently busy or unauthorized. Please check your API keys or try again later.";
  }

  /// Fetches last 7 days of logs + profile to build a grounding context for AI
  static Future<String> getGroundingContext() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return "User not logged in.";

    try {
      final profileDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final profile = profileDoc.data() ?? {};

      final logsCol = FirebaseFirestore.instance
          .collection('logs')
          .doc(user.uid)
          .collection('daily_entries');

      final now = DateTime.now();
      final last7Days = await logsCol
          .where(
            'timestamp',
            isGreaterThan: now.subtract(const Duration(days: 7)),
          )
          .orderBy('timestamp', descending: true)
          .get();

      StringBuffer context = StringBuffer();
      context.writeln("USER PROFILE:");
      context.writeln("- Name: ${profile['name'] ?? 'Not provided'}");
      context.writeln("- Age/DOB: ${profile['dob'] ?? 'Not provided'}");
      context.writeln("- Height: ${profile['height'] ?? 'Not provided'} cm");
      context.writeln("- Weight: ${profile['weight'] ?? 'Not provided'} kg");
      context.writeln(
        "- Life Stage / Condition: ${profile['lifeStage'] ?? 'None'}",
      );
      if (profile['lifeStage'] == 'pregnant') {
        context.writeln(
          "- Trimester: ${profile['trimester'] ?? 'Not provided'}",
        );
        context.writeln(
          "- Pregnancy Week: ${profile['pregnancyWeek'] ?? 'Not provided'}",
        );
      }

      context.writeln("\nRECENT HEALTH LOGS (LAST 7 DAYS):");
      if (last7Days.docs.isEmpty) {
        context.writeln("No logs found for the last 7 days.");
      } else {
        for (var doc in last7Days.docs) {
          final data = doc.data();
          final date = doc.id.split('_').first;
          final time = data['timeOfLog'] ?? 'Unknown';
          context.writeln("Date: $date ($time)");
          if (data['isOnPeriod'] != null) {
            context.writeln(
              "  - Status: ${data['isOnPeriod'] == true ? 'On Period (Day ${data['periodDay']})' : 'Not on period'}",
            );
          }
          context.writeln("  - Phase: ${data['periodPhase'] ?? 'N/A'}");
          context.writeln("  - Symptoms: ${data['symptoms'] ?? 'None'}");
          context.writeln("  - Mood: ${data['mood'] ?? 'General'}");
          context.writeln("  - Sleep: ${data['sleep'] ?? 'N/A'}");
          context.writeln("  - Activity: ${data['activity'] ?? 'N/A'}");
          context.writeln("  - Weight: ${data['weight'] ?? 'Same as profile'}");
          if (data['waist'] != null)
            context.writeln(
              "  - Waist: ${data['waist']} cm, Hip: ${data['hip']} cm",
            );
          if (data['ateFastFood'] != null)
            context.writeln("  - Fast Food Consumed: ${data['ateFastFood']}");
          // Pregnancy-specific log data
          if (data['nausea'] != null)
            context.writeln("  - Nausea: ${data['nausea']}");
          if (data['swelling'] != null)
            context.writeln("  - Swelling: ${data['swelling']}");
          if (data['babyKicks'] != null)
            context.writeln("  - Baby Kicks: ${data['babyKicks']}");
          if (data['prenatalVitamins'] != null)
            context.writeln(
              "  - Prenatal Vitamins: ${data['prenatalVitamins']}",
            );
          if (data['contractionNotes'] != null &&
              data['contractionNotes'].toString().isNotEmpty) {
            context.writeln(
              "  - Contraction Notes: ${data['contractionNotes']}",
            );
          }
          // Menopause-specific log data
          if (data['irregularBleeding'] == true)
            context.writeln("  - Irregular Bleeding: Yes");
          if (data['spotting'] == true) context.writeln("  - Spotting: Yes");
        }
      }

      return context.toString();
    } catch (e) {
      return "Error building AI context: $e";
    }
  }
}
