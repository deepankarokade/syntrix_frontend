# Quick Start Guide - Environment Setup

## 🚀 Get Started in 3 Steps

### Step 1: Copy the Environment File
```bash
cp .env.example .env
```

### Step 2: Add Your Credentials
Open `.env` and replace the placeholder values with your actual API keys:

```env
# Replace these with your actual values:
OPENROUTER_API_KEY=sk-or-v1-your-actual-key-here
CLOUDINARY_CLOUD_NAME=your-cloud-name
CLOUDINARY_UPLOAD_PRESET=your-preset
# ... etc
```

### Step 3: Run the App
```bash
flutter pub get
flutter run
```

## 📋 Where to Get Your Credentials

| Service | Where to Get It | Used In |
|---------|----------------|---------|
| **OpenRouter API** | [openrouter.ai](https://openrouter.ai/) | AI chat & diet features |
| **Cloudinary** | [cloudinary.com/console](https://cloudinary.com/console) | File uploads (reports, images) |
| **EmailJS** | [emailjs.com](https://www.emailjs.com/) | Welcome emails |
| **Firebase** | [console.firebase.google.com](https://console.firebase.google.com/) | Authentication, database |

## ⚠️ Important Notes

- **Never commit** the `.env` file to Git (it's already in `.gitignore`)
- **Never share** your API keys publicly
- **Use different keys** for development and production
- **Rotate keys** if they're ever exposed

## 🔍 Verify Your Setup

Run this to check if everything is configured:
```bash
flutter doctor
flutter pub get
```

If you see any errors about missing environment variables, double-check your `.env` file.

## 🆘 Troubleshooting

### "Unable to load asset: .env"
- Make sure `.env` file exists in the project root
- Verify it's listed in `pubspec.yaml` under assets
- Run `flutter clean` and `flutter pub get`

### "Environment variable not found"
- Check spelling in `.env` file
- Ensure no extra spaces around `=` sign
- Verify the variable name matches the code

### Services not working
- Confirm all required credentials are filled in `.env`
- Check that credentials are valid and active
- Review service-specific documentation

## 📚 More Information

- Full setup guide: `ENV_SETUP.md`
- Migration details: `ENVIRONMENT_MIGRATION.md`
- Firebase setup: `FIREBASE_SETUP.md`

---

**Need help?** Check the documentation files or contact your team lead.
