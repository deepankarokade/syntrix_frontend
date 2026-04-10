import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Sends transactional emails via EmailJS (https://www.emailjs.com).
///
/// Setup (one-time, free):
///   1. Create an account at https://www.emailjs.com
///   2. Add an Email Service (Gmail, Outlook, etc.) → note the SERVICE_ID
///   3. Create an Email Template with variables {{to_name}}, {{to_email}}
///      → note the TEMPLATE_ID
///   4. Copy your Public Key from Account → API Keys
///   5. Add these values to your .env file
class EmailService {
  // ── Credentials loaded from .env file ──────────────────────────────────
  static String get _serviceId => dotenv.env['EMAILJS_SERVICE_ID'] ?? '';
  static String get _templateId => dotenv.env['EMAILJS_TEMPLATE_ID'] ?? '';
  static String get _publicKey => dotenv.env['EMAILJS_PUBLIC_KEY'] ?? '';
  // ─────────────────────────────────────────────────────────────────────────

  /// Sends a welcome email to [toEmail] addressed to [toName].
  static Future<void> sendWelcomeEmail({
    required String toName,
    required String toEmail,
  }) async {
    const url = 'https://api.emailjs.com/api/v1.0/email/send';

    final body = jsonEncode({
      'service_id': _serviceId,
      'template_id': _templateId,
      'user_id': _publicKey,
      'template_params': {
        'to_name': toName,
        'to_email': toEmail,
        'app_name': 'Serene Cycle',
        'welcome_message':
            'We\'re so glad you\'re here. Serene Cycle is your personal space '
            'to track your hormonal health, understand your cycle, and take '
            'control of your wellbeing — one day at a time.\n\n'
            'Start by completing your profile and logging your first cycle. '
            'Our AI-powered insights will grow smarter with every entry you '
            'make.\n\n'
            'If you ever have questions, just reach out — we\'re here for you.',
      },
    });

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      if (response.statusCode == 200) {
        print('EmailService: Welcome email sent to $toEmail');
      } else {
        print('EmailService: Failed (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      // Non-blocking — a failed email must never crash sign-up
      print('EmailService: Exception sending email: $e');
    }
  }
}
