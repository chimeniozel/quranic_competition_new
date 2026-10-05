import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:quranic_competition/core/services/quranic_benefit_service.dart';
import 'package:quranic_competition/models/quranic_benefit.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_ui.dart';
import '../../../../core/widgets/loading_states.dart';
import '../../../../core/widgets/ui_components.dart';

/// Détail complet d'une فائدة قرآنية.
///
/// Ouverte depuis la liste (la فائدة est passée directement) ou depuis une
/// notification (seul son identifiant est connu : elle est alors chargée).
class BenefitDetailPage extends StatefulWidget {
  final String benefitId;
  final QuranicBenefit? benefit;

  const BenefitDetailPage({super.key, required this.benefitId, this.benefit});

  @override
  State<BenefitDetailPage> createState() => _BenefitDetailPageState();
}

class _BenefitDetailPageState extends State<BenefitDetailPage> {
  QuranicBenefit? _benefit;
  bool _isLoading = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _benefit = widget.benefit;
    if (_benefit == null) _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      final benefit = await QuranicBenefitService().getBenefitById(
        widget.benefitId,
      );
      if (!mounted) return;
      setState(() {
        // Une فائدة dépubliée n'est pas affichée aux participants
        _benefit = benefit != null && benefit.isActive ? benefit : null;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Erreur lors du chargement de la فائدة: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  void _share(QuranicBenefit benefit) {
    SharePlus.instance.share(
      ShareParams(
        text: '${benefit.title}\n\n${benefit.content}',
        subject: benefit.title,
      ),
    );
  }

  /// Ouverte depuis une notification, la page n'a rien sous elle : le
  /// retour mène alors à la liste des فوائد.
  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/participant/benefits');
    }
  }

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';

  @override
  Widget build(BuildContext context) {
    final benefit = _benefit;

    return Scaffold(
      appBar: AppBar(
        title: const Text('فائدة قرآنية'),
        leading: IconButton(
          icon: const BackButtonIcon(),
          tooltip: 'رجوع',
          onPressed: _back,
        ),
        actions: [
          if (benefit != null)
            IconButton(
              icon: const Icon(Icons.share_rounded),
              tooltip: 'مشاركة',
              onPressed: () => _share(benefit),
            ),
        ],
      ),
      body:
          _isLoading
              ? const ModernLoadingIndicator()
              : benefit == null
              ? _buildUnavailable()
              : _buildContent(benefit),
    );
  }

  Widget _buildUnavailable() {
    return Center(
      child: SingleChildScrollView(
        child: EmptyState(
          icon: _hasError ? Icons.wifi_off_rounded : Icons.menu_book_rounded,
          iconColor: _hasError ? AppTheme.errorColor : null,
          title: _hasError ? 'تعذر تحميل الفائدة' : 'الفائدة غير متاحة',
          subtitle:
              _hasError
                  ? 'تحقق من الاتصال وحاول مجدداً'
                  : 'ربما تم حذف هذه الفائدة أو إخفاؤها',
          action:
              _hasError
                  ? PrimaryButton(
                    text: 'إعادة المحاولة',
                    icon: Icons.refresh_rounded,
                    onPressed: _load,
                  )
                  : SecondaryButton(
                    text: 'كل الفوائد',
                    icon: Icons.menu_book_rounded,
                    onPressed: () => context.go('/participant/benefits'),
                  ),
        ),
      ),
    );
  }

  Future<void> _copy(QuranicBenefit benefit) async {
    await Clipboard.setData(
      ClipboardData(text: '${benefit.title}\n\n${benefit.content}'),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم نسخ الفائدة'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// Ornement doré : trait — ✦ — trait
  Widget _ornament() {
    Widget line() => Expanded(
      child: Container(
        height: 1,
        color: AppTheme.goldColor.withValues(alpha: 0.6),
      ),
    );

    return Row(
      children: [
        line(),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppTheme.spacingS),
          child: Icon(Icons.auto_awesome_rounded, size: 18, color: AppTheme.goldColor),
        ),
        line(),
      ],
    );
  }

  Widget _buildContent(QuranicBenefit benefit) {
    final hasImage = benefit.imageUrl != null && benefit.imageUrl!.isNotEmpty;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        AppGradientHeader(
          icon: Icons.menu_book_rounded,
          title: benefit.title,
          badges: [
            AppHeaderBadge(
              icon: Icons.calendar_today_rounded,
              text: _formatDate(benefit.createdAt),
            ),
            const AppHeaderBadge(icon: Icons.verified_rounded, text: 'فائدة قرآنية'),
          ],
        ),
        Padding(
          padding: const EdgeInsets.all(AppTheme.spacingM),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (hasImage) ...[
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppTheme.radiusL),
                    boxShadow: AppTheme.shadowM,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.network(
                    benefit.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder:
                        (context, error, stackTrace) => Container(
                          height: 180,
                          color: AppTheme.dividerColor,
                          child: const Center(
                            child: Icon(Icons.image_not_supported_rounded, size: 48),
                          ),
                        ),
                  ),
                ),
                const SizedBox(height: AppTheme.spacingM),
              ],
              // Texte de la فائدة, mis en valeur
              Container(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.spacingL,
                  AppTheme.spacingM,
                  AppTheme.spacingL,
                  AppTheme.spacingL,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundColor,
                  borderRadius: BorderRadius.circular(AppTheme.radiusL),
                  border: Border.all(
                    color: AppTheme.goldColor.withValues(alpha: 0.35),
                  ),
                  boxShadow: AppTheme.shadowS,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.format_quote_rounded,
                      size: 36,
                      color: AppTheme.goldColor,
                    ),
                    const SizedBox(height: AppTheme.spacingS),
                    // Sélectionnable : on peut en copier un passage
                    SelectableText(
                      benefit.content,
                      textAlign: TextAlign.justify,
                      style: AppTheme.bodyLarge.copyWith(
                        fontSize: 18,
                        height: 2,
                        color: AppTheme.textPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingL),
                    _ornament(),
                    const SizedBox(height: AppTheme.spacingS),
                    Text(
                      'مسابقة أهل القرآن الواتسابية',
                      textAlign: TextAlign.center,
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.secondaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.spacingM),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _copy(benefit),
                      style: AppButtonStyles.outlined(AppTheme.primaryColor),
                      icon: const Icon(Icons.copy_rounded),
                      label: const Text('نسخ'),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingS),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () => _share(benefit),
                      style: AppButtonStyles.filled(AppTheme.primaryColor),
                      icon: const Icon(Icons.share_rounded),
                      label: const Text('مشاركة الفائدة'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingL),
            ],
          ),
        ),
      ],
    );
  }
}
