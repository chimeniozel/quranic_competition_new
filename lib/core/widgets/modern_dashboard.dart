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
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(AppTheme.spacingS),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingS),
              decoration: BoxDecoration(
                color: cardColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
              ),
              child: Icon(icon, color: cardColor, size: 22),
            ),
            const SizedBox(width: AppTheme.spacingS),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: AppTheme.headingSmall.copyWith(
                    color: cardColor,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  title,
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.textSecondaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: AppTheme.labelSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          if (onTap != null)
            const Icon(Icons.chevron_left_rounded, color: AppTheme.textSecondaryColor),
        ],
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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding:
              padding ??
              const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingXS,
                vertical: AppTheme.spacingS,
              ),
          child: Row(
            children: [
              // Petit trait de couleur devant le titre
              Container(
                width: 4,
                height: subtitle != null ? 34 : 20,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: AppTheme.spacingS),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTheme.bodyLarge.copyWith(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
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
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: AppTheme.textSecondaryColor,
                  )
                  : null),
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingS,
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
        crossAxisSpacing: AppTheme.spacingS,
        mainAxisSpacing: AppTheme.spacingS,
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
              const SizedBox(width: AppTheme.spacingS),
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
          const SizedBox(height: AppTheme.spacingS),
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
          const SizedBox(width: AppTheme.spacingS),
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
                const SizedBox(height: AppTheme.spacingS),
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
              Icons.arrow_forward_ios_rounded,
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
  // Largeur / hauteur des tuiles (plus petit = tuiles plus hautes)
  final double childAspectRatio;

  const QuickActionGrid({
    super.key,
    required this.actions,
    this.crossAxisCount = 4,
    this.childAspectRatio = 1.2,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: AppTheme.spacingS,
        mainAxisSpacing: AppTheme.spacingS,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: actions.length,
      itemBuilder: (context, index) {
        final action = actions[index];
        // Tuile teintée de la couleur de l'action : ressort sur fond blanc
        return Material(
          color: action.color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(AppTheme.radiusL),
          child: InkWell(
            onTap: action.onTap,
            borderRadius: BorderRadius.circular(AppTheme.radiusL),
            child: Container(
              padding: const EdgeInsets.all(AppTheme.spacingS),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppTheme.radiusL),
                border: Border.all(color: action.color.withValues(alpha: 0.18)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppTheme.radiusM),
                      boxShadow: AppTheme.shadowS,
                    ),
                    child:
                        action.imagePath != null
                            ? Image.asset(
                              action.imagePath!,
                              fit: BoxFit.contain,
                              cacheWidth: 96,
                              cacheHeight: 96,
                              errorBuilder:
                                  (context, error, stackTrace) => Icon(
                                    action.icon ?? Icons.apps_rounded,
                                    color: action.color,
                                  ),
                            )
                            : Icon(
                              action.icon ?? Icons.apps_rounded,
                              color: action.color,
                              size: 26,
                            ),
                  ),
                  const SizedBox(height: AppTheme.spacingS),
                  Text(
                    action.title,
                    style: AppTheme.bodySmall.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimaryColor,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Modèle pour les actions rapides
class QuickAction {
  final String title;
  final IconData? icon;
  final String? imagePath;
  final Color color;
  final VoidCallback? onTap;

  const QuickAction({
    required this.title,
    this.icon,
    this.imagePath,
    required this.color,
    this.onTap,
  });
}
