import 'package:flutter/material.dart';

/// アプリケーション全体で使用するカラーパレット
class AppColors {
  AppColors._();

  // プライマリーカラー
  static const Color primary = Color(0xFF4CAF50);
  static const Color primaryLight = Color(0xFF81C784);
  static const Color primaryDark = Color(0xFF388E3C);

  // セカンダリーカラー
  static const Color secondary = Color(0xFF2196F3);
  static const Color secondaryLight = Color(0xFF64B5F6);
  static const Color secondaryDark = Color(0xFF1976D2);

  // アクセントカラー
  static const Color accent = Color(0xFFFF9800);
  static const Color accentLight = Color(0xFFFFB74D);
  static const Color accentDark = Color(0xFFF57C00);

  // ステータスカラー
  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFF44336);
  static const Color warning = Color(0xFFFF9800);
  static const Color info = Color(0xFF2196F3);

  // グレースケール
  static const Color grey50 = Color(0xFFFAFAFA);
  static const Color grey100 = Color(0xFFF5F5F5);
  static const Color grey200 = Color(0xFFEEEEEE);
  static const Color grey300 = Color(0xFFE0E0E0);
  static const Color grey400 = Color(0xFFBDBDBD);
  static const Color grey500 = Color(0xFF9E9E9E);
  static const Color grey600 = Color(0xFF757575);
  static const Color grey700 = Color(0xFF616161);
  static const Color grey800 = Color(0xFF424242);
  static const Color grey900 = Color(0xFF212121);

  // テキストカラー
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textDisabled = Color(0xFFBDBDBD);
  static const Color textOnPrimary = Colors.white;
  static const Color textOnSecondary = Colors.white;

  // 背景色
  static const Color background = Colors.white;
  static const Color backgroundSecondary = Color(0xFFF5F5F5);
  static const Color backgroundTertiary = Color(0xFFEEEEEE);

  // サーフェスカラー
  static const Color surface = Colors.white;
  static const Color surfaceVariant = Color(0xFFF5F5F5);

  // ボーダーカラー
  static const Color border = Color(0xFFE0E0E0);
  static const Color borderDark = Color(0xFFBDBDBD);

  // シャドウカラー
  static const Color shadow = Color(0x1F000000);
}
