// lib/widgets/common/dialog_theme.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// A class that provides consistent styling for dialogs throughout the app
class AppDialogTheme {
  final bool isDarkMode;

  // Constants for dialog styling
  static const double borderRadius = 16.0;
  static const EdgeInsets contentPadding = EdgeInsets.fromLTRB(24, 20, 24, 24);
  static const EdgeInsets actionsPadding = EdgeInsets.fromLTRB(24, 0, 24, 16);

  // Light Theme Colors
  static const Color _primaryDarkLight = Color(0xFF0D1F2D);
  static const Color _blueAccentLight = Color(0xFF2196F3);
  static const Color _greenAccentLight = Color(0xFF4CAF50);
  static const Color _backgroundColorLight = Color(0xFFFCF9F5);
  static const Color _surfaceColorLight = Colors.white;
  static const Color _textColorLight = _primaryDarkLight;
  static const Color _secondaryTextColorLight = Color(0xFF6c757d);
  static const Color _iconBackgroundColorLight = Color(0xFFf1f3f5);

  // Dark Theme Colors
  static const Color _primaryDarkDark = Color(0xFFFFFFFF);
  static const Color _blueAccentDark = Color(0xFF64b5f6);
  static const Color _greenAccentDark = Color(0xFF81c784);
  static const Color _backgroundColorDark = Color(0xFF121212);
  static const Color _surfaceColorDark = Color(0xFF1E1E1E);
  static const Color _textColorDark = Colors.white;
  static const Color _secondaryTextColorDark = Color(0xFFadb5bd);
  static const Color _iconBackgroundColorDark = Color(0xFF343a40);

  AppDialogTheme({required this.isDarkMode});

  // Theme-dependent colors
  Color get primaryColor => isDarkMode ? _primaryDarkDark : _primaryDarkLight;
  Color get blueAccent => isDarkMode ? _blueAccentDark : _blueAccentLight;
  Color get greenAccent => isDarkMode ? _greenAccentDark : _greenAccentLight;
  Color get backgroundColor => isDarkMode ? _backgroundColorDark : _backgroundColorLight;
  Color get surfaceColor => isDarkMode ? _surfaceColorDark : _surfaceColorLight;
  Color get textColor => isDarkMode ? _textColorDark : _textColorLight;
  Color get secondaryTextColor => isDarkMode ? _secondaryTextColorDark : _secondaryTextColorLight;
  Color get iconBackgroundColor => isDarkMode ? _iconBackgroundColorDark : _iconBackgroundColorLight;

  // Animated dialog builder with enhanced animations
  static Widget animatedDialogBuilder(BuildContext context, Widget? child) {
    return child!
        .animate()
        .scale(
          duration: const Duration(milliseconds: 300),
          curve: Curves.elasticOut,
          begin: const Offset(0.8, 0.8),
          end: const Offset(1.0, 1.0),
        )
        .fadeIn(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        )
        .slideY(
          begin: 0.1,
          end: 0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutQuart,
        );
  }

  // Enhanced dialog decoration with gradient and modern styling
  BoxDecoration get dialogDecoration => BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: (isDarkMode ? Colors.black : _primaryDarkLight).withOpacity(0.08),
            blurRadius: 32,
            offset: const Offset(0, 16),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: (isDarkMode ? Colors.black : _primaryDarkLight).withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      );

  // Header decoration with gradient
  BoxDecoration getHeaderDecoration(Color accentColor) => BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accentColor,
            accentColor.withOpacity(0.8),
          ],
          stops: const [0.0, 1.0],
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(borderRadius),
          topRight: Radius.circular(borderRadius),
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      );

  // Text styles with improved typography
  TextStyle get headerTitleStyle => const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: Colors.white,
        letterSpacing: 0.5,
      );

  TextStyle get titleStyle => TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: primaryColor,
        letterSpacing: 0.3,
      );

  TextStyle get contentStyle => TextStyle(
        fontSize: 16,
        color: primaryColor.withOpacity(0.7),
        height: 1.4,
        letterSpacing: 0.1,
      );

  TextStyle get labelStyle => TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: primaryColor.withOpacity(0.8),
        letterSpacing: 0.2,
      );

  // Enhanced button styles
  ButtonStyle getCancelButtonStyle() => TextButton.styleFrom(
        foregroundColor: primaryColor.withOpacity(0.7),
        minimumSize: const Size(120, 48),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: primaryColor.withOpacity(0.2),
            width: 1.5,
          ),
        ),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      );
  
  ButtonStyle getConfirmButtonStyle(Color backgroundColor) => FilledButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: backgroundColor,
        minimumSize: const Size(120, 48),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        elevation: 4,
        shadowColor: backgroundColor.withOpacity(0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.3,
        ),
      );
  
  // Enhanced input decoration with modern styling
  InputDecoration getInputDecoration(String label, {IconData? prefixIcon, Color? accentColor}) {
    final effectiveAccentColor = accentColor ?? blueAccent;
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: primaryColor.withOpacity(0.6),
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      prefixIcon: prefixIcon != null
        ? Container(
            margin: const EdgeInsets.only(right: 12),
            child: Icon(
              prefixIcon,
              size: 22,
              color: effectiveAccentColor.withOpacity(0.7),
            ),
          )
        : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: primaryColor.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: primaryColor.withOpacity(0.15),
          width: 1.5,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: effectiveAccentColor,
          width: 2.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: Colors.red,
          width: 2,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: Colors.red,
          width: 2.5,
        ),
      ),
      filled: true,
      fillColor: backgroundColor.withOpacity(0.3),
      hintStyle: TextStyle(
        color: primaryColor.withOpacity(0.4),
        fontSize: 14,
      ),
    );
  }

  // Utility method for creating feature cards
  Widget buildFeatureCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: textColor.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
