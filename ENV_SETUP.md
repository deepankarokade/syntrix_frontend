# Environment Variables Setup Guide

This project uses environment variables to store sensitive data like API keys and credentials.

## Setup Instructions

1. **Copy the example file:**
   ```bash
   cp .env.example .env
   ```

2. **Fill in your actual credentials** in the `.env` file:
   - Replace all placeholder values with your actual API keys and credentials
   - Never commit the `.env` file to version control (it's already in `.gitignore`)

## Required Credentials

### 1. OpenRouter AI Service
- **OPENROUTER_API_KEY**: Get from [OpenRouter](https://openrouter.ai/)
- Used in: `lib/services/ai_service.dart`

### 2. Cloudinary Service
- **CLOUDINARY_CLOUD_NAME**: Your Cloudinary cloud name
- **CLOUDINARY_UPLOAD_PRESET**: Your upload preset name
- Get from: [Cloudinary Dashboard](https://cloudinary.com/console)
- Used in: `lib/services/cloudinary_service.dart`

### 3. EmailJS Service
- **EMAILJS_SERVICE_ID**: Your EmailJS service ID
- **EMAILJS_TEMPLATE_ID**: Your email template ID
- **EMAILJS_PUBLIC_KEY**: Your EmailJS public key
- Get from: [EmailJS Dashboard](https://www.emailjs.com/)
- Used in: `lib/services/email_service.dart`

### 4. Firebase Configuration
- **Firebase Web & Android Keys**: Get from [Firebase Console](https://console.firebase.google.com/)
- Used in: `lib/firebase_options.dart`

## Security Notes

⚠️ **IMPORTANT:**
- Never commit the `.env` file to Git
- Never share your API keys publicly
- Rotate keys immediately if they are exposed
- Use different keys for development and production environments

## For Flutter/Dart Projects

To use environment variables in Flutter, you'll need to:

1. Add the `flutter_dotenv` package to `pubspec.yaml`:
   ```yaml
   dependencies:
     flutter_dotenv: ^5.1.0
   ```

2. Load the `.env` file in your `main.dart`:
   ```dart
   import 'package:flutter_dotenv/flutter_dotenv.dart';
   
   Future<void> main() async {
     await dotenv.load(fileName: ".env");
     runApp(MyApp());
   }
   ```

3. Add `.env` to your `pubspec.yaml` assets:
   ```yaml
   flutter:
     assets:
       - .env
   ```

4. Access variables in your code:
   ```dart
   import 'package:flutter_dotenv/flutter_dotenv.dart';
   
   final apiKey = dotenv.env['OPENROUTER_API_KEY'];
   ```

## Next Steps

After setting up the `.env` file, you'll need to update the service files to read from environment variables instead of hardcoded values. See the individual service files for implementation details.
