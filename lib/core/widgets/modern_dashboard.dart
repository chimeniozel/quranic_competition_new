import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'ui_components.dart';

/// Widgets pour créer des dashboards modernes

/// Card de statistique moderne
class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData? icon;
  final Color? color;
  final VoidCallback? onTap;
  final String? subtitle;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    this.icon,
    this.color,
    this.onTap,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = color ?? AppTheme.primaryColor;

    return ModernCard(
      onTap: onTap,
      padding: const EdgeInsets.all(8),
      child: Container(
        height: 80,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: cardColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(icon, color: cardColor, size: 14),
                  ),
                  const SizedBox(width: 4),
                ],
                const Spacer(),
                if (onTap != null)
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 10,
                    color: AppTheme.textSecondaryColor,
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: AppTheme.bodyMedium.copyWith(
                color: cardColor,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 1),
            Text(
              title,
              style: AppTheme.bodySmall.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 1),
              Text(
                subtitle!,
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.textSecondaryColor,
                  fontSize: 8,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Section de dashboard avec titre et actions
class DashboardSection extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final List<Widget>? actions;
  final EdgeInsetsGeometry? padding;

  const DashboardSection({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    this.actions,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: padding ?? const EdgeInsets.all(AppTheme.spacingM),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTheme.headingSmall),
                    if (subtitle != null) ...[
                      const SizedBox(height: AppTheme.spacingXS),
                      Text(
                        subtitle!,
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.textSecondaryColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (actions != null) ...actions!,
            ],
          ),
        ),
        child,
      ],
    );
  }
}

/// Liste moderne avec éléments personnalisés
class ModernListTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? leadingIcon;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? iconColor;
  final bool showDivider;

  const ModernListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leadingIcon,
    this.trailing,
    this.onTap,
    this.iconColor,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          leading:
              leadingIcon != null
                  ? Container(
                    padding: const EdgeInsets.all(AppTheme.spacingS),
                    decoration: BoxDecoration(
                      color: (iconColor ?? AppTheme.primaryColor).withValues(
                        alpha: 0.1,
                      ),
                      borderRadius: BorderRadius.circular(AppTheme.radiusS),
                    ),
                    child: Icon(
                      leadingIcon,
                      color: iconColor ?? AppTheme.primaryColor,
                      size: 20,
                    ),
                  )
                  : null,
          title: Text(
            title,
            style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.w600),
          ),
          subtitle:
              subtitle != null
                  ? Text(subtitle!, style: AppTheme.bodyMedium)
                  : null,
          trailing:
              trailing ??
              (onTap != null
                  ? Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: AppTheme.textSecondaryColor,
                  )
                  : null),
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingM,
            vertical: AppTheme.spacingS,
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            color: AppTheme.dividerColor,
            indent: AppTheme.spacingL,
          ),
      ],
    );
  }
}

/// Grille de statistiques
class StatsGrid extends StatelessWidget {
  final List<StatCard> stats;
  final int crossAxisCount;

  const StatsGrid({super.key, required this.stats, this.crossAxisCount = 2});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: AppTheme.spacingM,
        mainAxisSpacing: AppTheme.spacingM,
        childAspectRatio: 2.8,
      ),
      itemCount: stats.length,
      itemBuilder: (context, index) => stats[index],
    );
  }
}

/// Widget de progression moderne
class ModernProgressCard extends StatelessWidget {
  final String title;
  final double progress;
  final String progressText;
  final IconData icon;
  final Color? color;
  final String? subtitle;

  const ModernProgressCard({
    super.key,
    required this.title,
    required this.progress,
    required this.progressText,
    required this.icon,
    this.color,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = color ?? AppTheme.primaryColor;

    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: cardColor, size: 24),
              const SizedBox(width: AppTheme.spacingM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTheme.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.textSecondaryColor,
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                progressText,
                style: AppTheme.bodyMedium.copyWith(
                  color: cardColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingM),
          ModernProgressIndicator(value: progress, color: cardColor, height: 6),
        ],
      ),
    );
  }
}

/// Widget de notification moderne
class ModernNotificationCard extends StatelessWidget {
  final String title;
  final String message;
  final DateTime timestamp;
  final IconData icon;
  final Color? color;
  final VoidCallback? onTap;
  final bool isRead;

  const ModernNotificationCard({
    super.key,
    required this.title,
    required this.message,
    required this.timestamp,
    required this.icon,
    this.color,
    this.onTap,
    this.isRead = false,
  });

  @override
  Widget build(BuildContext context) {
    final notificationColor = color ?? AppTheme.infoColor;

    return ModernCard(
      onTap: onTap,
      backgroundColor:
          isRead
              ? AppTheme.backgroundColor
              : notificationColor.withValues(alpha: 0.05),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingS),
            decoration: BoxDecoration(
              color: notificationColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusS),
            ),
            child: Icon(icon, color: notificationColor, size: 20),
          ),
          const SizedBox(width: AppTheme.spacingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: AppTheme.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                          color:
                              isRead
                                  ? AppTheme.textPrimaryColor
                                  : notificationColor,
                        ),
                      ),
                    ),
                    Text(
                      _formatTimestamp(timestamp),
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacingXS),
                Text(
                  message,
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.textSecondaryColor,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (onTap != null)
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: AppTheme.textSecondaryColor,
            ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'الآن';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}د';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}س';
    } else {
      return '${difference.inDays}ي';
    }
  }
}

/// Widget de menu rapide
class QuickActionGrid extends StatelessWidget {
  final List<QuickAction> actions;
  final int crossAxisCount;

  const QuickActionGrid({
    super.key,
    required this.actions,
    this.crossAxisCount = 4,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: AppTheme.spacingM,
        mainAxisSpacing: AppTheme.spacingM,
        childAspectRatio: 1.4,
      ),
      itemCount: actions.length,
      itemBuilder: (context, index) {
        final action = actions[index];
        return ModernCard(
          onTap: action.onTap,
          padding: const EdgeInsets.all(AppTheme.spacingS),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: action.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                ),
                child: Icon(action.icon, color: action.color, size: 20),
              ),
              const SizedBox(height: 6),
              Text(
                action.title,
                style: AppTheme.bodySmall.copyWith(fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Modèle pour les actions rapides
class QuickAction {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const QuickAction({
    required this.title,
    required this.icon,
    required this.color,
    this.onTap,
  });
}
