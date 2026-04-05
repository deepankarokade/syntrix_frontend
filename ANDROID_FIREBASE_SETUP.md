# Android Firebase Setup Guide

## Current Status
✅ Web Firebase configuration is complete
✅ Android build files updated with Google Services plugin
⏳ Need Android app configuration from Firebase Console

## Steps to Complete Android Setup

### 1. Add Android App in Firebase Console

1. Go to: https://console.firebase.google.com/project/syntrix-430f9/settings/general
2. Scroll down to "Your apps" section
3. Click "Add app" button
4. Select the **Android** icon
5. Fill in the form:
   - **Android package name**: `com.example.syntrix`
   - **App nickname** (optional): Syntrix Android
   - **Debug signing certificate SHA-1** (optional for now, needed for Google Sign-In)
6. Click "Register app"

### 2. Download google-services.json

1. After registering, Firebase will provide a `google-services.json` file
2. Click "Download google-services.json"
3. Place this file in: `android/app/google-services.json`

### 3. Get Android Configuration Values

From the Firebase Console or the `google-services.json` file, you'll need:
- **mobilesdk_app_id**: Something like `1:1082037001747:android:xxxxxxxxxxxxx`
- **api_key**: The Android API key (usually starts with `AIzaSy...`)

### 4. Update firebase_options.dart

Once you have the Android app ID and API key, update `lib/firebase_options.dart`:

```dart
static const FirebaseOptions android = FirebaseOptions(
  apiKey: 'YOUR_ANDROID_API_KEY',
  appId: 'YOUR_ANDROID_APP_ID',
  messagingSenderId: '1082037001747',
  projectId: 'syntrix-430f9',
  authDomain: 'syntrix-430f9.firebaseapp.com',
  storageBucket: 'syntrix-430f9.firebasestorage.app',
);
```

### 5. Enable Authentication

1. Go to: https://console.firebase.google.com/project/syntrix-430f9/authentication/providers
2. Click on "Email/Password"
3. Toggle "Enable"
4. Click "Save"

### 6. (Optional) For Google Sign-In on Android

If you want Google Sign-In to work on Android:

1. Get your SHA-1 certificate fingerprint:
   ```bash
   cd android
   ./gradlew signingReport
   ```
   
2. Copy the SHA-1 from the debug variant

3. Add it to Firebase:
   - Go to Project Settings → Your Android app
   - Click "Add fingerprint"
   - Paste the SHA-1
   - Download the updated `google-services.json`

### 7. Test Your App

Run on Android:
```bash
flutter run
```

Run on Web (for testing):
```bash
flutter run -d chrome
```

## Current Configuration

### Package Name
- Android: `com.example.syntrix`

### Firebase Project
- Project ID: `syntrix-430f9`
- Project Number: `1082037001747`

### Configured Platforms
- ✅ Web (fully configured)
- ⏳ Android (needs google-services.json and app ID)

## Troubleshooting

### Error: "No Firebase App"
- Make sure `google-services.json` is in `android/app/`
- Run `flutter clean` and rebuild

### Error: "API key not valid"
- Check that you've enabled Email/Password authentication in Firebase Console
- Verify the API key in `firebase_options.dart` matches Firebase Console

### Google Sign-In not working
- Add SHA-1 fingerprint to Firebase Console
- Download updated `google-services.json`
- Make sure Google Sign-In is enabled in Firebase Console

## Next Steps

1. Complete steps 1-4 above to get Android configuration
2. Share the Android app ID and API key with me
3. I'll update the `firebase_options.dart` file
4. Test signup/login on both Android and Web
