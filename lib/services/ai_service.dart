import 'dart:convert';
import 'package:http/http.dart' as http;

class AiService {
  static const String _apiKey = "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";
  static const String _apiUrl = "https://openrouter.ai/api/v1/chat/completions";

  static const String chatSystemPrompt = """
You are a HIGH-PRECISION Women's Health AI Assistant.

STRICT RULES:
- NO hallucinations
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
- ZERO hallucination
- NEVER assume missing values
- If required data is missing → ASK QUESTIONS FIRST
- Use only medically accepted clinical ranges
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
        "model": "qwen/qwen-2.5-72b-instruct",
        "messages": messages,
        "temperature": 0.2,
        "max_tokens": 1500,
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
}
