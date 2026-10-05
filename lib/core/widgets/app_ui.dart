import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Composants visuels communs (pages d'administration et du compte).
///
/// Même langage partout : cartes blanches arrondies à ombre douce, en-têtes
/// avec icône teintée, badges discrets et boutons plats.

/// Section : carte blanche avec en-tête (icône teintée, titre, sous-titre)
class AppSection extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;
  final Color? borderColor;
  final EdgeInsetsGeometry? margin;

  const AppSection({
    super.key,
    required this.icon,
    required this.title,
    required this.child,
    this.color,
    this.subtitle,
    this.trailing,
    this.borderColor,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final accent = color ?? AppTheme.primaryColor;

    return Container(
      margin: margin,
      padding: const EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        boxShadow: AppTheme.shadowS,
        border:
            borderColor != null
                ? Border.all(color: borderColor!.withValues(alpha: 0.35))
                : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              AppIconBadge(icon: icon, color: accent),
              const SizedBox(width: AppTheme.spacingS),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTheme.bodyLarge.copyWith(
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
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: AppTheme.spacingM),
          child,
        ],
      ),
    );
  }
}

/// Petite icône sur fond teinté
class AppIconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;

  const AppIconBadge({
    super.key,
    required this.icon,
    required this.color,
    this.size = 20,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingS),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
      ),
      child: Icon(icon, color: color, size: size),
    );
  }
}

/// Encadré d'information (conseil, avertissement, état)
class AppNotice extends StatelessWidget {
  final String text;
  final Color color;
  final IconData icon;

  const AppNotice({
    super.key,
    required this.text,
    this.color = AppTheme.infoColor,
    this.icon = Icons.info_outline_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingS),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: AppTheme.spacingS),
          Expanded(
            child: Text(
              text,
              style: AppTheme.bodySmall.copyWith(color: color, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

/// Badge discret : texte (et icône) sur fond teinté
class AppTag extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;

  const AppTag({super.key, required this.text, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusS),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 3),
          ],
          Text(
            text,
            style: AppTheme.labelSmall.copyWith(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Forme de l'en-tête
enum AppHeaderShape {
  /// Pleine largeur, coins arrondis en bas (haut de page)
  banner,

  /// Carte arrondie avec ombre (dans une liste avec marges)
  card,
}

/// En-tête dégradé partagé par toutes les pages.
///
/// Les couleurs sont identiques dans toute l'application : le dégradé
/// principal du thème ([AppTheme.primaryGradient]), volontairement non
/// paramétrable pour garder un en-tête uniforme.
///
/// - [shape] : bandeau de haut de page ou carte arrondie ;
/// - [compact] : disposition en ligne (icône, textes, [trailing]) au lieu de
///   la disposition centrée ;
/// - [bottom] : contenu affiché sous l'en-tête (progression, sélecteur...).
class AppGradientHeader extends StatelessWidget {
  final Widget? leading;
  final IconData? icon;
  final String title;
  final String? subtitle;
  final List<Widget> badges;
  final AppHeaderShape shape;
  final bool compact;
  final Widget? trailing;
  final Widget? bottom;

  const AppGradientHeader({
    super.key,
    required this.title,
    this.leading,
    this.icon,
    this.subtitle,
    this.badges = const [],
    this.shape = AppHeaderShape.banner,
    this.compact = false,
    this.trailing,
    this.bottom,
  });

  Widget? get _leadingWidget {
    if (leading != null) return leading;
    if (icon == null) return null;
    final size = compact ? 24.0 : 34.0;
    return CircleAvatar(
      radius: compact ? 24 : 34,
      backgroundColor: Colors.white.withValues(alpha: 0.2),
      child: Icon(icon, size: size, color: Colors.white),
    );
  }

  Widget _buildCentered() {
    final lead = _leadingWidget;
    return Column(
      children: [
        if (lead != null) ...[lead, const SizedBox(height: AppTheme.spacingS)],
        Text(
          title,
          textAlign: TextAlign.center,
          style: AppTheme.headingMedium.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            style: AppTheme.bodyMedium.copyWith(
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
        ],
        if (badges.isNotEmpty) ...[
          const SizedBox(height: AppTheme.spacingS),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: AppTheme.spacingS,
            runSpacing: AppTheme.spacingXS,
            children: badges,
          ),
        ],
      ],
    );
  }

  Widget _buildCompact() {
    final lead = _leadingWidget;
    return Row(
      children: [
        if (lead != null) ...[lead, const SizedBox(width: AppTheme.spacingS)],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTheme.headingSmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: AppTheme.bodySmall.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              if (badges.isNotEmpty) ...[
                const SizedBox(height: AppTheme.spacingXS),
                Wrap(
                  spacing: AppTheme.spacingXS,
                  runSpacing: AppTheme.spacingXS,
                  children: badges,
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: AppTheme.spacingS),
          trailing!,
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCard = shape == AppHeaderShape.card;
    final radius =
        isCard
            ? BorderRadius.circular(AppTheme.radiusXL)
            : const BorderRadius.vertical(
              bottom: Radius.circular(AppTheme.radiusXL),
            );

    final header = Container(
      width: double.infinity,
      padding:
          isCard
              ? const EdgeInsets.all(AppTheme.spacingM)
              : const EdgeInsets.fromLTRB(
                AppTheme.spacingM,
                AppTheme.spacingM,
                AppTheme.spacingM,
                AppTheme.spacingL,
              ),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: radius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          compact ? _buildCompact() : _buildCentered(),
          if (bottom != null) ...[
            const SizedBox(height: AppTheme.spacingM),
            bottom!,
          ],
        ],
      ),
    );

    // Liseré doré (couleur du logo) : en bas du bandeau, tout autour de la
    // carte
    return Container(
      padding:
          isCard ? const EdgeInsets.all(1.5) : const EdgeInsets.only(bottom: 3),
      decoration: BoxDecoration(
        color: AppTheme.goldColor,
        borderRadius:
            isCard
                ? BorderRadius.circular(AppTheme.radiusXL + 1.5)
                : const BorderRadius.vertical(
                  bottom: Radius.circular(AppTheme.radiusXL + 1),
                ),
        boxShadow: isCard ? AppTheme.shadowM : null,
      ),
      child: header,
    );
  }
}

/// Barre de progression blanche, à placer dans [AppGradientHeader.bottom]
class AppHeaderProgress extends StatelessWidget {
  final double value;
  final String? label;
  final String? trailingText;

  const AppHeaderProgress({
    super.key,
    required this.value,
    this.label,
    this.trailingText,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (label != null || trailingText != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                if (label != null)
                  Expanded(
                    child: Text(
                      label!,
                      style: AppTheme.bodySmall.copyWith(color: Colors.white),
                    ),
                  ),
                if (trailingText != null)
                  Text(
                    trailingText!,
                    style: AppTheme.bodyLarge.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value.clamp(0.0, 1.0),
            minHeight: 6,
            color: Colors.white,
            backgroundColor: Colors.white.withValues(alpha: 0.25),
          ),
        ),
      ],
    );
  }
}

/// Badge blanc translucide, à placer dans [AppGradientHeader]
class AppHeaderBadge extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? highlightColor;

  const AppHeaderBadge({
    super.key,
    required this.icon,
    required this.text,
    this.highlightColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingS,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: highlightColor ?? Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            text,
            style: AppTheme.labelMedium.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Carte de liste cliquable : élément d'une liste (utilisateur, version,
/// règle, niveau...)
class AppListCard extends StatelessWidget {
  final Widget? leading;
  final String title;
  final String? subtitle;
  final List<Widget> tags;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? highlightColor;
  final EdgeInsetsGeometry margin;

  const AppListCard({
    super.key,
    required this.title,
    this.leading,
    this.subtitle,
    this.tags = const [],
    this.trailing,
    this.onTap,
    this.highlightColor,
    this.margin = const EdgeInsets.only(bottom: AppTheme.spacingS),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        boxShadow: AppTheme.shadowS,
        border:
            highlightColor != null
                ? Border.all(color: highlightColor!.withValues(alpha: 0.4))
                : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusL),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingS),
            child: Row(
              children: [
                if (leading != null) ...[
                  leading!,
                  const SizedBox(width: AppTheme.spacingS),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTheme.bodyLarge.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitle != null && subtitle!.isNotEmpty)
                        Text(
                          subtitle!,
                          style: AppTheme.bodySmall.copyWith(
                            color: AppTheme.textSecondaryColor,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (tags.isNotEmpty) ...[
                        const SizedBox(height: AppTheme.spacingXS),
                        Wrap(
                          spacing: AppTheme.spacingXS,
                          runSpacing: AppTheme.spacingXS,
                          children: tags,
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null)
                  trailing!
                else if (onTap != null)
                  const Icon(
                    Icons.chevron_left_rounded,
                    color: AppTheme.textSecondaryColor,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Statistique compacte (chiffre + libellé), cliquable si [onTap]
class AppStatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback? onTap;

  const AppStatTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color:
          selected ? color.withValues(alpha: 0.16) : AppTheme.backgroundColor,
      borderRadius: BorderRadius.circular(AppTheme.radiusM),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            vertical: AppTheme.spacingS,
            horizontal: AppTheme.spacingXS,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusM),
            border: Border.all(
              color: selected ? color : color.withValues(alpha: 0.18),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 2),
              Text(
                value,
                style: AppTheme.headingSmall.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                label,
                textAlign: TextAlign.center,
                style: AppTheme.labelSmall.copyWith(
                  color: AppTheme.textSecondaryColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Styles de boutons communs
class AppButtonStyles {
  AppButtonStyles._();

  static const _padding = EdgeInsets.symmetric(vertical: 14, horizontal: 16);

  static RoundedRectangleBorder get _shape => RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppTheme.radiusM),
  );

  static ButtonStyle filled(Color color) => ElevatedButton.styleFrom(
    backgroundColor: color,
    foregroundColor: Colors.white,
    elevation: 0,
    shape: _shape,
    padding: _padding,
  );

  static ButtonStyle outlined(Color color) => OutlinedButton.styleFrom(
    foregroundColor: color,
    side: BorderSide(color: color.withValues(alpha: 0.6)),
    shape: _shape,
    padding: _padding,
  );
}

/// Indicateur de chargement pour l'intérieur d'un bouton
class AppButtonLoader extends StatelessWidget {
  final Color color;

  const AppButtonLoader({super.key, this.color = Colors.white});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      height: 18,
      child: CircularProgressIndicator(strokeWidth: 2, color: color),
    );
  }
}
