import 'package:flutter/material.dart';
import '../../foundation/spacing.dart';
import '../../foundation/radius.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import 'primary_button.dart';

/// セカンダリーボタンコンポーネント（アウトライン）
class SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final PrimaryButtonSize size;
  final IconData? icon;
  final bool isLoading;
  final bool fullWidth;
  final Color? borderColor;

  const SecondaryButton({
    Key? key,
    required this.label,
    this.onPressed,
    this.size = PrimaryButtonSize.medium,
    this.icon,
    this.isLoading = false,
    this.fullWidth = true,
    this.borderColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final buttonBorderColor = borderColor ?? theme.colorScheme.primary;

    Widget content = _buildButtonContent();

    return OutlinedButton(
      onPressed: isLoading ? null : onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: buttonBorderColor,
        disabledForegroundColor: AppColors.textDisabled,
        side: BorderSide(color: buttonBorderColor, width: 2),
        padding: _getPadding(),
        minimumSize: fullWidth ? Size(double.infinity, _getHeight()) : Size(0, _getHeight()),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        textStyle: _getTextStyle(),
      ),
      child: content,
    );
  }

  Widget _buildButtonContent() {
    if (isLoading) {
      return SizedBox(
        width: _getIconSize(),
        height: _getIconSize(),
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation<Color>(
            borderColor ?? AppColors.primary,
          ),
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
          vertical: AppSpacing.lg,
        );
      case PrimaryButtonSize.large:
        return EdgeInsets.symmetric(
          horizontal: AppSpacing.xxxl,
          vertical: AppSpacing.xl,
        );
    }
  }

  double _getHeight() {
    switch (size) {
      case PrimaryButtonSize.small:
        return 44.0;
      case PrimaryButtonSize.medium:
        return 56.0;
      case PrimaryButtonSize.large:
        return 64.0;
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
        return 18.0;
      case PrimaryButtonSize.medium:
        return 22.0;
      case PrimaryButtonSize.large:
        return 26.0;
    }
  }
}
