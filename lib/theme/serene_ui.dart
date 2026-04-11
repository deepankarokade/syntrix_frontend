import 'package:flutter/material.dart';

class SereneColors {
  // Primary brand colors
  static const Color primary = Color(0xFF2E4A6B);
  static const Color secondary = Color(0xFF3A6EA8);
  static const Color accent = Color(0xFFB5616A);
  
  // Neutral colors
  static const Color background = Color(0xFFF8FAFF);
  static const Color surface = Colors.white;
  static const Color cardBg = Color(0xFFF4F6FA);
  
  // Text colors
  static const Color textPrimary = Color(0xFF1A2B3C);
  static const Color textSecondary = Color(0xFF7A8FA6);
  static const Color textLight = Colors.white;
  
  // Status colors
  static const Color success = Color(0xFF2E7D6B);
  static const Color warning = Color(0xFFE59A2F);
  static const Color error = Color(0xFFB5616A);
}

class SereneStyles {
  static final BorderRadius cardRadius = BorderRadius.circular(20);
  static final BorderRadius buttonRadius = BorderRadius.circular(16);
  
  static final List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.05),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ];
  
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF3A6EA8), Color(0xFF2E4A6B)],
  );

  static const LinearGradient successGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2E7D6B), Color(0xFF1A5C4E)],
  );
}
