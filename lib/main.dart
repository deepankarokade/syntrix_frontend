import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';
import 'screens/onboarding/welcome_screen.dart';
import 'widgets/auth_wrapper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme/serene_ui.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables
  await dotenv.load(fileName: ".env");
  
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final prefs = await SharedPreferences.getInstance();
  final hasSeenWelcome = prefs.getBool('hasSeenWelcome') ?? false;

  runApp(MyApp(hasSeenWelcome: hasSeenWelcome));
}

class MyApp extends StatelessWidget {
  final bool hasSeenWelcome;
  
  const MyApp({super.key, required this.hasSeenWelcome});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Serene Cycle',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: SereneColors.primary,
        scaffoldBackgroundColor: SereneColors.background,
        cardColor: SereneColors.surface,
        colorScheme: ColorScheme.fromSeed(
          seedColor: SereneColors.primary,
          primary: SereneColors.primary,
          secondary: SereneColors.secondary,
          surface: SereneColors.surface,
          error: SereneColors.error,
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(color: SereneColors.textPrimary, fontWeight: FontWeight.w800),
          titleLarge: TextStyle(color: SereneColors.primary, fontWeight: FontWeight.w700),
          titleMedium: TextStyle(color: SereneColors.primary, fontWeight: FontWeight.w700),
          bodyLarge: TextStyle(color: SereneColors.textPrimary),
          bodyMedium: TextStyle(color: SereneColors.textSecondary),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          titleTextStyle: TextStyle(
            color: SereneColors.primary,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
          iconTheme: IconThemeData(color: SereneColors.primary),
        ),
      ),
      home: hasSeenWelcome ? const AuthWrapper() : const WelcomeScreen(),
    );
  }
}
