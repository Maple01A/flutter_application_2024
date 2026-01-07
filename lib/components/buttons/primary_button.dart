import 'package:flutter/material.dart';
import '../../foundation/spacing.dart';
import '../../foundation/radius.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// プライマリーボタンのサイズ
enum PrimaryButtonSize {
  small,
  medium,
  large,
}

/// プライマリーボタンコンポーネント
class PrimaryButton extends StatelessWidget {
  /// ボタンのラベル
  final String label;

  /// ボタン押下時のコールバック
  final VoidCallback? onPressed;

  /// ボタンのサイズ
  final PrimaryButtonSize size;

  /// アイコン（オプション）
  final IconData? icon;

  /// ローディング状態
  final bool isLoading;

  /// 全幅表示
  final bool fullWidth;

  /// カスタム背景色
  final Color? backgroundColor;

  const PrimaryButton({
    Key? key,
    required this.label,
    this.onPressed,
    this.size = PrimaryButtonSize.medium,
    this.icon,
    this.isLoading = false,
    this.fullWidth = false,
    this.backgroundColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final buttonColor = backgroundColor ?? theme.colorScheme.primary;

    Widget content = _buildButtonContent();

    final button = ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: buttonColor,
        foregroundColor: AppColors.textOnPrimary,
        disabledBackgroundColor: AppColors.grey300,
        disabledForegroundColor: AppColors.textDisabled,
        elevation: 2,
        shadowColor: AppColors.shadow,
        padding: _getPadding(),
        minimumSize: fullWidth ? const Size(double.infinity, 0) : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        textStyle: _getTextStyle(),
      ),
      child: content,
    );

    return button;
  }

  Widget _buildButtonContent() {
    if (isLoading) {
      return SizedBox(
        width: _getIconSize(),
        height: _getIconSize(),
        child: const CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.textOnPrimary),
        ),
      );
    }

    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: _getIconSize()),
          SizedBox(width: AppSpacing.sm),
          Text(label),
        ],
      );
    }

    return Text(label);
  }

  EdgeInsets _getPadding() {
    switch (size) {
      case PrimaryButtonSize.small:
        return EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        );
      case PrimaryButtonSize.medium:
        return EdgeInsets.symmetric(
          horizontal: AppSpacing.xxl,
          vertical: AppSpacing.md,
        );
      case PrimaryButtonSize.large:
        return EdgeInsets.symmetric(
          horizontal: AppSpacing.xxxl,
          vertical: AppSpacing.lg,
        );
    }
  }

  TextStyle _getTextStyle() {
    switch (size) {
      case PrimaryButtonSize.small:
        return AppTextStyles.buttonSmall;
      case PrimaryButtonSize.medium:
        return AppTextStyles.button;
      case PrimaryButtonSize.large:
        return AppTextStyles.buttonLarge;
    }
  }

  double _getIconSize() {
    switch (size) {
      case PrimaryButtonSize.small:
        return 16.0;
      case PrimaryButtonSize.medium:
        return 20.0;
      case PrimaryButtonSize.large:
        return 24.0;
    }
  }
}
