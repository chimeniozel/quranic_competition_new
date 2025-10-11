import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'ui_components.dart';

/// Widgets pour gérer les états de chargement et d'erreur

/// Indicateur de chargement moderne
class ModernLoadingIndicator extends StatelessWidget {
  final String? message;
  final double size;
  final Color? color;
  final bool showMessage;

  const ModernLoadingIndicator({
    super.key,
    this.message,
    this.size = 40,
    this.color,
    this.showMessage = true,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(
                color ?? AppTheme.primaryColor,
              ),
            ),
          ),
          if (showMessage && message != null) ...[
            const SizedBox(height: AppTheme.spacingM),
            Text(
              message!,
              style: AppTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

/// État de chargement avec skeleton
class LoadingSkeleton extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;
  final Color? color;

  const LoadingSkeleton({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = AppTheme.radiusS,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color ?? AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: _ShimmerEffect(
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        ),
      ),
    );
  }
}

/// Skeleton pour les listes
class ListSkeleton extends StatelessWidget {
  final int itemCount;
  final double itemHeight;
  final EdgeInsetsGeometry? padding;

  const ListSkeleton({
    super.key,
    this.itemCount = 5,
    this.itemHeight = 80,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsets.all(AppTheme.spacingM),
      child: Column(
        children: List.generate(
          itemCount,
          (index) => Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.spacingM),
            child: LoadingSkeleton(
              width: double.infinity,
              height: itemHeight,
              borderRadius: AppTheme.radiusM,
            ),
          ),
        ),
      ),
    );
  }
}

/// Skeleton pour les cards
class CardSkeleton extends StatelessWidget {
  final double height;
  final EdgeInsetsGeometry? margin;

  const CardSkeleton({super.key, this.height = 200, this.margin});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? const EdgeInsets.all(AppTheme.spacingS),
      child: LoadingSkeleton(
        width: double.infinity,
        height: height,
        borderRadius: AppTheme.radiusM,
      ),
    );
  }
}

/// État vide avec illustration
class EmptyState extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color? iconColor;
  final Widget? action;
  final double iconSize;

  const EmptyState({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = Icons.inbox_outlined,
    this.iconColor,
    this.action,
    this.iconSize = 64,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingXL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: iconSize,
              color: iconColor ?? AppTheme.textDisabledColor,
            ),
            const SizedBox(height: AppTheme.spacingL),
            Text(
              title,
              style: AppTheme.headingSmall.copyWith(
                color: AppTheme.textSecondaryColor,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: AppTheme.spacingS),
              Text(
                subtitle!,
                style: AppTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: AppTheme.spacingL),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// État d'erreur avec retry
class ErrorState extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback? onRetry;
  final String retryText;

  const ErrorState({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = Icons.error_outline,
    this.onRetry,
    this.retryText = 'إعادة المحاولة',
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingXL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: AppTheme.errorColor),
            const SizedBox(height: AppTheme.spacingL),
            Text(
              title,
              style: AppTheme.headingSmall.copyWith(color: AppTheme.errorColor),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: AppTheme.spacingS),
              Text(
                subtitle!,
                style: AppTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: AppTheme.spacingL),
              PrimaryButton(
                text: retryText,
                onPressed: onRetry,
                icon: Icons.refresh,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// État de succès avec animation
class SuccessState extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? action;
  final bool showAnimation;

  const SuccessState({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
    this.showAnimation = true,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingXL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showAnimation)
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 800),
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppTheme.successColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check_circle,
                        size: 48,
                        color: AppTheme.successColor,
                      ),
                    ),
                  );
                },
              )
            else
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppTheme.successColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle,
                  size: 48,
                  color: AppTheme.successColor,
                ),
              ),
            const SizedBox(height: AppTheme.spacingL),
            Text(
              title,
              style: AppTheme.headingSmall.copyWith(
                color: AppTheme.successColor,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: AppTheme.spacingS),
              Text(
                subtitle!,
                style: AppTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: AppTheme.spacingL),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Widget de shimmer effect pour les skeletons
class _ShimmerEffect extends StatefulWidget {
  final Widget child;

  const _ShimmerEffect({required this.child});

  @override
  State<_ShimmerEffect> createState() => _ShimmerEffectState();
}

class _ShimmerEffectState extends State<_ShimmerEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = Tween<double>(
      begin: -1.0,
      end: 2.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Colors.transparent,
                Colors.white.withOpacity(0.4),
                Colors.transparent,
              ],
              stops: [
                _animation.value - 0.3,
                _animation.value,
                _animation.value + 0.3,
              ],
            ).createShader(bounds);
          },
          child: widget.child,
        );
      },
    );
  }
}

/// Pull to refresh moderne
class ModernPullToRefresh extends StatelessWidget {
  final Widget child;
  final Future<void> Function() onRefresh;
  final Color? color;

  const ModernPullToRefresh({
    super.key,
    required this.child,
    required this.onRefresh,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: color ?? AppTheme.primaryColor,
      backgroundColor: Colors.white,
      strokeWidth: 2,
      child: child,
    );
  }
}

/// Loading overlay pour les opérations
class LoadingOverlay extends StatelessWidget {
  final Widget child;
  final bool isLoading;
  final String? message;
  final Color? color;

  const LoadingOverlay({
    super.key,
    required this.child,
    this.isLoading = false,
    this.message,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Container(
            color: (color ?? Colors.black).withOpacity(0.5),
            child: ModernLoadingIndicator(
              message: message,
              color: Colors.white,
            ),
          ),
      ],
    );
  }
}
