import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Composants UI réutilisables pour l'application

/// Bouton principal avec style moderne
class PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final bool fullWidth;
  final Color? backgroundColor;
  final Color? textColor;

  const PrimaryButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.fullWidth = false,
    this.backgroundColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: fullWidth ? double.infinity : null,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor ?? AppTheme.primaryColor,
          foregroundColor: textColor ?? Colors.white,
          elevation: AppTheme.elevationS,
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingL,
            vertical: AppTheme.spacingS,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusM),
          ),
        ),
        child:
            isLoading
                ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
                : Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 18, color: textColor ?? Colors.white),
                      const SizedBox(width: AppTheme.spacingXS),
                    ],
                    Flexible(
                      child: Text(
                        text,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: textColor ?? Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
      ),
    );
  }
}

/// Bouton secondaire avec bordure
class SecondaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final bool fullWidth;
  final Color? borderColor;
  final Color? textColor;

  const SecondaryButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.fullWidth = false,
    this.borderColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: fullWidth ? double.infinity : null,
      child: OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: textColor ?? AppTheme.primaryColor,
          side: BorderSide(
            color: borderColor ?? AppTheme.primaryColor,
            width: 1.5,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingL,
            vertical: AppTheme.spacingS,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusM),
          ),
        ),
        child:
            isLoading
                ? SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      textColor ?? AppTheme.primaryColor,
                    ),
                  ),
                )
                : Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[
                      Icon(
                        icon,
                        size: 18,
                        color: textColor ?? AppTheme.primaryColor,
                      ),
                      const SizedBox(width: AppTheme.spacingXS),
                    ],
                    Flexible(
                      child: Text(
                        text,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: textColor ?? AppTheme.primaryColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
      ),
    );
  }
}

/// Card moderne avec ombre
class ModernCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;
  final double? elevation;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;

  const ModernCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.backgroundColor,
    this.elevation,
    this.borderRadius,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? const EdgeInsets.all(AppTheme.spacingS),
      decoration: BoxDecoration(
        color: backgroundColor ?? AppTheme.cardColor,
        borderRadius: borderRadius ?? BorderRadius.circular(AppTheme.radiusM),
        boxShadow: AppTheme.shadowS,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius ?? BorderRadius.circular(AppTheme.radiusM),
          child: Padding(
            padding: padding ?? const EdgeInsets.all(AppTheme.spacingS),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Badge de statut coloré
class StatusBadge extends StatelessWidget {
  final String text;
  final String status;
  final bool isActive;
  final IconData? icon;

  const StatusBadge({
    super.key,
    required this.text,
    this.status = 'active',
    this.isActive = true,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        isActive
            ? AppTheme.statusColors[status] ?? AppTheme.successColor
            : AppTheme.textDisabledColor;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingS,
        vertical: AppTheme.spacingS,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusS),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Avatar personnalisé avec initiales
class CustomAvatar extends StatelessWidget {
  final String? imageUrl;
  final String? initials;
  final double size;
  final Color? backgroundColor;
  final Color? textColor;
  final IconData? fallbackIcon;

  const CustomAvatar({
    super.key,
    this.imageUrl,
    this.initials,
    this.size = 40,
    this.backgroundColor,
    this.textColor,
    this.fallbackIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor ?? AppTheme.primaryColor,
        shape: BoxShape.circle,
        boxShadow: AppTheme.shadowS,
      ),
      child: ClipOval(
        child:
            imageUrl != null
                ? Image.network(
                  imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder:
                      (context, error, stackTrace) => _buildFallback(),
                )
                : _buildFallback(),
      ),
    );
  }

  Widget _buildFallback() {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? AppTheme.primaryColor,
        shape: BoxShape.circle,
      ),
      child:
          initials != null && initials!.isNotEmpty
              ? Center(
                child: Text(
                  initials!.substring(0, 1).toUpperCase(),
                  style: TextStyle(
                    color: textColor ?? Colors.white,
                    fontSize: size * 0.4,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
              : Icon(
                fallbackIcon ?? Icons.person,
                color: textColor ?? Colors.white,
                size: size * 0.5,
              ),
    );
  }
}

/// Champ de saisie moderne
class ModernTextField extends StatelessWidget {
  final String? label;
  final String? hint;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool enabled;
  final int? maxLines;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;

  const ModernTextField({
    super.key,
    this.label,
    this.hint,
    this.controller,
    this.validator,
    this.obscureText = false,
    this.keyboardType,
    this.prefixIcon,
    this.suffixIcon,
    this.enabled = true,
    this.maxLines = 1,
    this.onTap,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      obscureText: obscureText,
      keyboardType: keyboardType,
      enabled: enabled,
      maxLines: maxLines,
      onTap: onTap,
      onChanged: onChanged,
      textDirection:
          keyboardType == TextInputType.emailAddress ? TextDirection.ltr : null,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        filled: true,
        fillColor:
            enabled
                ? AppTheme.surfaceColor
                : AppTheme.surfaceColor.withValues(alpha: 0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
          borderSide: const BorderSide(color: AppTheme.dividerColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
          borderSide: const BorderSide(color: AppTheme.dividerColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
          borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
          borderSide: const BorderSide(color: AppTheme.errorColor),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
          borderSide: const BorderSide(color: AppTheme.errorColor, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingS,
          vertical: AppTheme.spacingS,
        ),
      ),
    );
  }
}

/// Indicateur de progression moderne
class ModernProgressIndicator extends StatelessWidget {
  final double value;
  final String? label;
  final Color? color;
  final double height;

  const ModernProgressIndicator({
    super.key,
    required this.value,
    this.label,
    this.color,
    this.height = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(label!, style: AppTheme.bodyMedium),
          const SizedBox(height: AppTheme.spacingS),
        ],
        ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusS),
          child: LinearProgressIndicator(
            value: value.clamp(0.0, 1.0),
            backgroundColor: AppTheme.dividerColor,
            valueColor: AlwaysStoppedAnimation<Color>(
              color ?? AppTheme.primaryColor,
            ),
            minHeight: height,
          ),
        ),
      ],
    );
  }
}

/// Divider moderne avec texte
class ModernDivider extends StatelessWidget {
  final String? text;
  final Color? color;

  const ModernDivider({super.key, this.text, this.color});

  @override
  Widget build(BuildContext context) {
    if (text == null) {
      return Divider(color: color ?? AppTheme.dividerColor, thickness: 1);
    }

    return Row(
      children: [
        Expanded(
          child: Divider(color: color ?? AppTheme.dividerColor, thickness: 1),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingS),
          child: Text(text!, style: AppTheme.bodySmall),
        ),
        Expanded(
          child: Divider(color: color ?? AppTheme.dividerColor, thickness: 1),
        ),
      ],
    );
  }
}

/// Alert moderne avec icône
class ModernAlert extends StatelessWidget {
  final String message;
  final String type; // 'info', 'success', 'warning', 'error'
  final IconData? icon;
  final VoidCallback? onClose;

  const ModernAlert({
    super.key,
    required this.message,
    this.type = 'info',
    this.icon,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _getColorsForType(type);

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingS),
      decoration: BoxDecoration(
        color: colors['background'],
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        border: Border.all(color: colors['border']!),
      ),
      child: Row(
        children: [
          Icon(icon ?? _getIconForType(type), color: colors['icon'], size: 20),
          const SizedBox(width: AppTheme.spacingS),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: colors['text'],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (onClose != null)
            IconButton(
              onPressed: onClose,
              icon: const Icon(Icons.close, size: 18),
              color: colors['icon'],
            ),
        ],
      ),
    );
  }

  Map<String, Color> _getColorsForType(String type) {
    switch (type) {
      case 'success':
        return {
          'background': AppTheme.successColor.withValues(alpha: 0.1),
          'border': AppTheme.successColor.withValues(alpha: 0.3),
          'icon': AppTheme.successColor,
          'text': AppTheme.successColor,
        };
      case 'warning':
        return {
          'background': AppTheme.warningColor.withValues(alpha: 0.1),
          'border': AppTheme.warningColor.withValues(alpha: 0.3),
          'icon': AppTheme.warningColor,
          'text': AppTheme.warningColor,
        };
      case 'error':
        return {
          'background': AppTheme.errorColor.withValues(alpha: 0.1),
          'border': AppTheme.errorColor.withValues(alpha: 0.3),
          'icon': AppTheme.errorColor,
          'text': AppTheme.errorColor,
        };
      default:
        return {
          'background': AppTheme.infoColor.withValues(alpha: 0.1),
          'border': AppTheme.infoColor.withValues(alpha: 0.3),
          'icon': AppTheme.infoColor,
          'text': AppTheme.infoColor,
        };
    }
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'success':
        return Icons.check_circle_outline;
      case 'warning':
        return Icons.warning_amber_outlined;
      case 'error':
        return Icons.error_outline;
      default:
        return Icons.info_outline;
    }
  }
}

/// شريط بحث حديث مع تصميم متطور
class ModernSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;

  const ModernSearchBar({
    super.key,
    required this.controller,
    required this.hintText,
    this.onChanged,
    this.onClear,
    this.margin,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final hasText = controller.text.isNotEmpty;

    return Container(
      margin: margin ?? const EdgeInsets.all(AppTheme.spacingS),
      padding: padding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.backgroundColor,
            AppTheme.backgroundColor.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        border: Border.all(
          color: AppTheme.primaryColor.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: AppTheme.bodyMedium.copyWith(
            color: AppTheme.textDisabledColor,
          ),
          prefixIcon: Container(
            margin: const EdgeInsets.all(AppTheme.spacingXS),
            padding: const EdgeInsets.all(AppTheme.spacingXS),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
              boxShadow: AppTheme.shadowS,
            ),
            child: const Icon(
              Icons.search,
              color: Colors.white,
              size: 18,
            ),
          ),
          suffixIcon: hasText
              ? IconButton(
                  icon: const Icon(
                    Icons.clear,
                    color: AppTheme.textSecondaryColor,
                    size: 20,
                  ),
                  onPressed: () {
                    controller.clear();
                    onChanged?.call('');
                    onClear?.call();
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingS,
            vertical: AppTheme.spacingS,
          ),
          filled: false,
        ),
        style: AppTheme.bodyMedium.copyWith(
          color: AppTheme.textPrimaryColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// Helper functions for modern dialogs using AppTheme
class ModernDialog {
  /// Shows a modern error dialog
  static void showError(
    BuildContext context, {
    required String title,
    required String message,
    String? confirmText,
    VoidCallback? onConfirm,
    bool barrierDismissible = false,
  }) {
    showDialog(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusL),
          ),
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                color: AppTheme.errorColor,
                size: 24,
              ),
              const SizedBox(width: AppTheme.spacingS),
              Flexible(
                child: Text(
                  title,
                  style: AppTheme.headingSmall.copyWith(
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            message,
            style: AppTheme.bodyMedium,
          ),
          actions: [
            TextButton(
              onPressed: onConfirm ?? () => Navigator.of(context).pop(),
              child: Text(
                confirmText ?? 'موافق',
                style: TextStyle(color: AppTheme.primaryColor),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Shows a modern success dialog
  static void showSuccess(
    BuildContext context, {
    required String title,
    required String message,
    String? confirmText,
    VoidCallback? onConfirm,
    bool barrierDismissible = false,
  }) {
    showDialog(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusL),
          ),
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle_outline,
                color: AppTheme.successColor,
                size: 24,
              ),
              const SizedBox(width: AppTheme.spacingS),
              Flexible(
                child: Text(
                  title,
                  style: AppTheme.headingSmall.copyWith(
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            message,
            style: AppTheme.bodyMedium,
          ),
          actions: [
            TextButton(
              onPressed: onConfirm ?? () => Navigator.of(context).pop(),
              child: Text(
                confirmText ?? 'موافق',
                style: TextStyle(color: AppTheme.primaryColor),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Shows a modern warning dialog
  static void showWarning(
    BuildContext context, {
    required String title,
    required String message,
    String? confirmText,
    VoidCallback? onConfirm,
    bool barrierDismissible = false,
  }) {
    showDialog(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusL),
          ),
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.warning_amber_outlined,
                color: AppTheme.warningColor,
                size: 24,
              ),
              const SizedBox(width: AppTheme.spacingS),
              Flexible(
                child: Text(
                  title,
                  style: AppTheme.headingSmall.copyWith(
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            message,
            style: AppTheme.bodyMedium,
          ),
          actions: [
            TextButton(
              onPressed: onConfirm ?? () => Navigator.of(context).pop(),
              child: Text(
                confirmText ?? 'موافق',
                style: TextStyle(color: AppTheme.primaryColor),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Shows a modern info dialog
  static void showInfo(
    BuildContext context, {
    required String title,
    required String message,
    String? confirmText,
    VoidCallback? onConfirm,
    bool barrierDismissible = false,
  }) {
    showDialog(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusL),
          ),
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.info_outline,
                color: AppTheme.infoColor,
                size: 24,
              ),
              const SizedBox(width: AppTheme.spacingS),
              Flexible(
                child: Text(
                  title,
                  style: AppTheme.headingSmall.copyWith(
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            message,
            style: AppTheme.bodyMedium,
          ),
          actions: [
            TextButton(
              onPressed: onConfirm ?? () => Navigator.of(context).pop(),
              child: Text(
                confirmText ?? 'موافق',
                style: TextStyle(color: AppTheme.primaryColor),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Shows a modern confirmation dialog
  static Future<bool?> showConfirm(
    BuildContext context, {
    required String title,
    required String message,
    String? confirmText,
    String? cancelText,
    Color? confirmColor,
    bool barrierDismissible = true,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusL),
          ),
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.help_outline,
                color: AppTheme.warningColor,
                size: 24,
              ),
              const SizedBox(width: AppTheme.spacingS),
              Flexible(
                child: Text(
                  title,
                  style: AppTheme.headingSmall.copyWith(
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            message,
            style: AppTheme.bodyMedium,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                cancelText ?? 'إلغاء',
                style: TextStyle(color: AppTheme.textSecondaryColor),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                confirmText ?? 'تأكيد',
                style: TextStyle(
                  color: confirmColor ?? AppTheme.primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
