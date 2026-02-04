import 'package:flutter/material.dart';

class AppColors {
  // Primary Colors
  static const Color primaryBlack = Color(0xFF1A1A1A);
  static const Color pureWhite = Color(0xFFFFFFFF);
  static const Color accentGray = Color(0xFFF5F5F5);
  
  // IXON Collaboration Colors
  static const Color xtonSilver = Color(0xFFC0C0C0);
  static const Color xtonGlow = Color(0xFFE0E0E0);
  
  // Status Colors
  static const Color successGreen = Color(0xFF4CAF50);
  static const Color primaryGreen = Color(0xFF4CAF50);
  static const Color warningYellow = Color(0xFFFFC107);
  static const Color errorRed = Color(0xFFF44336);
  static const Color infoBlue = Color(0xFF2196F3);
  
  // UI Colors
  static const Color background = pureWhite;
  static const Color surface = accentGray;
  static const Color onPrimary = pureWhite;
  static const Color onBackground = primaryBlack;
  static const Color onSurface = Color(0xFF666666);
  
  // Border Colors
  static const Color borderLight = Color(0xFFE0E0E0);
  static const Color borderDark = Color(0xFF333333);
  
  // Text Colors
  static const Color textPrimary = primaryBlack;
  static const Color textSecondary = Color(0xFF666666);
  static const Color textDisabled = Color(0xFF999999);
  
  // Button Colors
  static const Color buttonPrimary = primaryBlack;
  static const Color buttonSecondary = accentGray;
  static const Color buttonDisabled = Color(0xFFCCCCCC);
  
  // Stock Level Colors
  static const Color stockLow = errorRed;
  static const Color stockMedium = warningYellow;
  static const Color stockGood = successGreen;
  
  // Order Status Colors
  static const Color statusPending = warningYellow;
  static const Color statusPaid = infoBlue;
  static const Color statusPreparing = Color(0xFF9C27B0);
  static const Color statusReady = successGreen;
  static const Color statusCompleted = Color(0xFF607D8B);
  static const Color statusCancelled = errorRed;
}
