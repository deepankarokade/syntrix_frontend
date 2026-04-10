import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ReportExtractionService {
  static String get _apiKey => dotenv.env['OPENROUTER_REPORT_API_KEY'] ?? '';
  static String get _modelId => dotenv.env['OPENROUTER_REPORT_MODEL_ID'] ?? 'google/gemma-4-31b-it:free';
  static const String _apiUrl = 'https://openrouter.ai/api/v1/chat/completions';

  static const String systemPrompt = """
You are a medical report text extraction AI. Your task is to extract ALL text content from medical reports, lab results, prescriptions, and health documents.

INSTRUCTIONS:
1. Extract ALL visible text from the document
2. Preserve the structure and formatting as much as possible
3. Include all medical values, test names, dates, and patient information
4. Organize the extracted text in a clear, readable format
5. If you see tables, preserve the table structure
6. Include headers, footers, and any notes

OUTPUT FORMAT:
- Use clear sections with headers
- Preserve numerical values exactly as shown
- Include units of measurement
- Maintain chronological order if dates are present
- Use bullet points or tables where appropriate

IMPORTANT:
- Extract EVERYTHING you can see
- Do NOT interpret or analyze the results
- Do NOT provide medical advice
- Just extract the text content accurately
""";

  /// Extract text from a medical report image and parse medical values
  static Future<Map<String, dynamic>> extractAndParseReport({
    required Uint8List imageBytes,
    required String fileName,
  }) async {
    try {
      // Convert bytes to base64
      final base64Image = base64Encode(imageBytes);
      final mimeType = _getMimeType(fileName);

      print('📤 Sending request to OpenRouter API...');
      print('   Model: $_modelId');
      print('   Image size: ${imageBytes.length} bytes');
      print('   MIME type: $mimeType');

      final payload = {
        "model": _modelId,
        "messages": [
          {
            "role": "system",
            "content": """You are a medical report data extraction AI. Extract medical test values from lab reports and return them in JSON format.

CRITICAL INSTRUCTIONS:
1. Extract ANY medical values you can find in the image
2. Return a valid JSON object with the extracted values
3. Use these field names when you find them: age, bmi, rbs, tsh, hb, whr, lh, fsh, amh, prl, prg
4. If a field is not found, simply omit it from the JSON
5. Extract ONLY numerical values (remove units like mg/dL, mIU/L, etc.)
6. For ratios like WHR, convert to decimal (e.g., 0.85)
7. If you find ANY medical values at all, include them

FIELD DEFINITIONS (extract if found):
- age: Patient age in years
- bmi: Body Mass Index (e.g., 24.5)
- rbs: Random Blood Sugar in mg/dL (e.g., 110)
- tsh: Thyroid Stimulating Hormone in mIU/L (e.g., 2.5)
- hb: Hemoglobin in g/dL (e.g., 12.8)
- whr: Waist to Hip Ratio as decimal (e.g., 0.85)
- lh: Luteinizing Hormone in mIU/mL (e.g., 5.2)
- fsh: Follicle Stimulating Hormone in mIU/mL (e.g., 6.1)
- amh: Anti-Müllerian Hormone in ng/mL (e.g., 3.5)
- prl: Prolactin in ng/mL (e.g., 15.2)
- prg: Progesterone in ng/mL (e.g., 8.5)

EXAMPLES OF VALID RESPONSES:
Example 1 (full report):
{"bmi": 24.5, "rbs": 110, "tsh": 2.5, "hb": 12.8, "lh": 5.2, "fsh": 6.1}

Example 2 (partial report):
{"tsh": 3.2, "hb": 13.1}

Example 3 (single value):
{"bmi": 22.8}

IMPORTANT: 
- Return ONLY the JSON object, no other text
- Even if you find just ONE value, return it
- Do not add explanations or comments
- The JSON must be valid and parseable""",
          },
          {
            "role": "user",
            "content": [
              {
                "type": "text",
                "text": "Extract all medical test values from this report image and return as JSON. Include any values you can find.",
              },
              {
                "type": "image_url",
                "image_url": {
                  "url": "data:$mimeType;base64,$base64Image",
                },
              },
            ],
          },
        ],
        "temperature": 0.1,
        "max_tokens": 1000,
      };

      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          "Authorization": "Bearer $_apiKey",
          "HTTP-Referer": "http://localhost",
          "X-Title": "Medical Report Extractor",
          "Content-Type": "application/json",
        },
        body: jsonEncode(payload),
      ).timeout(
        const Duration(seconds: 60),
        onTimeout: () => throw TimeoutException('Request timed out'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        print('═══════════════════════════════════════════════════════');
        print('🤖 AI RESPONSE RECEIVED');
        print('═══════════════════════════════════════════════════════');
        
        if (data["choices"] != null && data["choices"].isNotEmpty) {
          final content = data["choices"][0]["message"]["content"];
          
          print('📄 RAW AI RESPONSE:');
          print(content);
          print('───────────────────────────────────────────────────────');
          
          // Try to parse the JSON response
          try {
            // Clean the content - remove markdown code blocks if present
            String cleanedContent = content.trim();
            cleanedContent = cleanedContent.replaceAll('```json', '');
            cleanedContent = cleanedContent.replaceAll('```', '');
            cleanedContent = cleanedContent.trim();
            
            print('🧹 CLEANED CONTENT:');
            print(cleanedContent);
            print('───────────────────────────────────────────────────────');
            
            // Extract JSON from the response
            final jsonMatch = RegExp(r'\{[^{}]*\}').firstMatch(cleanedContent);
            if (jsonMatch != null) {
              final jsonStr = jsonMatch.group(0)!;
              
              print('🔍 EXTRACTED JSON STRING:');
              print(jsonStr);
              print('───────────────────────────────────────────────────────');
              
              final parsedData = jsonDecode(jsonStr) as Map<String, dynamic>;
              
              print('✅ PARSED JSON DATA:');
              print(parsedData);
              print('───────────────────────────────────────────────────────');
              
              // Convert all values to proper types
              final cleanedData = <String, dynamic>{};
              parsedData.forEach((key, value) {
                if (value != null) {
                  if (value is num) {
                    cleanedData[key] = value.toDouble();
                    print('  ✓ $key: ${value.toDouble()} (converted from num)');
                  } else if (value is String) {
                    final numValue = double.tryParse(value);
                    if (numValue != null) {
                      cleanedData[key] = numValue;
                      print('  ✓ $key: $numValue (converted from string)');
                    } else {
                      print('  ⚠ $key: "$value" (could not convert to number)');
                    }
                  }
                }
              });
              
              print('───────────────────────────────────────────────────────');
              print('📊 FINAL EXTRACTED DATA:');
              cleanedData.forEach((key, value) {
                print('  • $key: $value');
              });
              print('═══════════════════════════════════════════════════════');
              
              if (cleanedData.isEmpty) {
                print('❌ NO VALID MEDICAL VALUES FOUND');
                print('═══════════════════════════════════════════════════════');
                return {
                  'success': false,
                  'error': 'No valid medical values found in the report',
                  'rawText': content,
                };
              }
              
              print('✅ EXTRACTION SUCCESSFUL - ${cleanedData.length} fields found');
              print('═══════════════════════════════════════════════════════');
              
              return {
                'success': true,
                'extractedData': cleanedData,
                'rawText': content,
                'model': _modelId,
              };
            } else {
              print('❌ COULD NOT FIND JSON IN RESPONSE');
              print('═══════════════════════════════════════════════════════');
              return {
                'success': false,
                'error': 'Could not find JSON in response',
                'rawText': content,
              };
            }
          } catch (e) {
            print('❌ PARSING ERROR: $e');
            print('═══════════════════════════════════════════════════════');
            return {
              'success': false,
              'error': 'Failed to parse response: $e',
              'rawText': content,
            };
          }
        } else {
          print('❌ NO CHOICES IN RESPONSE');
          print('═══════════════════════════════════════════════════════');
          return {
            'success': false,
            'error': 'No response from AI model',
          };
        }
      } else {
        print('❌ API ERROR: ${response.statusCode}');
        print('Response body: ${response.body}');
        print('═══════════════════════════════════════════════════════');
        return {
          'success': false,
          'error': 'API Error: ${response.statusCode}\n${response.body}',
        };
      }
    } catch (e) {
      print('❌ EXCEPTION OCCURRED: $e');
      print('═══════════════════════════════════════════════════════');
      return {
        'success': false,
        'error': 'Exception: $e',
      };
    }
  }

  /// Extract text from a report URL (already uploaded to cloud)
  static Future<Map<String, dynamic>> extractTextFromReportUrl({
    required String imageUrl,
  }) async {
    try {
      final payload = {
        "model": _modelId,
        "messages": [
          {
            "role": "system",
            "content": systemPrompt,
          },
          {
            "role": "user",
            "content": [
              {
                "type": "text",
                "text": "Please extract all text from this medical report image. Include all visible information.",
              },
              {
                "type": "image_url",
                "image_url": {
                  "url": imageUrl,
                },
              },
            ],
          },
        ],
        "temperature": 0.1,
        "max_tokens": 4000,
      };

      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          "Authorization": "Bearer $_apiKey",
          "HTTP-Referer": "http://localhost",
          "X-Title": "Medical Report Extractor",
          "Content-Type": "application/json",
        },
        body: jsonEncode(payload),
      ).timeout(
        const Duration(seconds: 60),
        onTimeout: () => throw TimeoutException('Request timed out'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["choices"] != null && data["choices"].isNotEmpty) {
          final extractedText = data["choices"][0]["message"]["content"];
          return {
            'success': true,
            'extractedText': extractedText,
            'model': _modelId,
          };
        } else {
          return {
            'success': false,
            'error': 'No response from AI model',
          };
        }
      } else {
        return {
          'success': false,
          'error': 'API Error: ${response.statusCode}\n${response.body}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Exception: $e',
      };
    }
  }

  /// Determine MIME type from file extension
  static String _getMimeType(String filePath) {
    final extension = filePath.split('.').last.toLowerCase();
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'pdf':
        return 'application/pdf';
      default:
        return 'image/jpeg';
    }
  }
}
