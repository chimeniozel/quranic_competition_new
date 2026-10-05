import 'package:flutter/material.dart';
import 'package:quranic_competition/core/widgets/app_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:quranic_competition/models/competition_version.dart';
import 'package:quranic_competition/models/round.dart';
import 'package:quranic_competition/core/services/round_results_service.dart';
import 'package:quranic_competition/core/services/round_service.dart';
import 'package:quranic_competition/core/theme/app_theme.dart';
import 'package:quranic_competition/core/widgets/ui_components.dart';
import 'package:quranic_competition/core/widgets/loading_states.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class VersionRoundResultPage extends StatefulWidget {
  final CompetitionVersion version;

  const VersionRoundResultPage({super.key, required this.version});

  @override
  State<VersionRoundResultPage> createState() => _VersionRoundResultPageState();
}

class _VersionRoundResultPageState extends State<VersionRoundResultPage> {
  final RoundResultsService _resultsService = RoundResultsService();
  final RoundService _roundService = RoundService();

  List<Round> _rounds = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRounds();
  }

  Future<void> _loadRounds() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final rounds = await _roundService.getRoundsByVersion(widget.version.id);
      setState(() {
        _rounds = rounds;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<bool> _checkCalculationAllowed() async {
    try {
      final supabase = Supabase.instance.client;
      final version =
          await supabase
              .from('competition_versions')
              .select(
                'is_active, is_registration_open, jury_evaluation_enabled, name',
              )
              .eq('id', widget.version.id)
              .single();

      final bool isActive = version['is_active'] == true;
      final bool isRegistrationOpen = version['is_registration_open'] == true;
      final bool juryEnabled = version['jury_evaluation_enabled'] == true;

      if (!isActive) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('لا يمكن حساب النتائج لأن النسخة غير مفعلة'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
        return false;
      }

      if (isRegistrationOpen) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('أغلق التسجيل أولاً قبل حساب النتائج'),
              backgroundColor: AppTheme.warningColor,
            ),
          );
        }
        return false;
      }

      if (juryEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'أوقف تقييم المحكّمين أولاً قبل حساب النتائج',
              ),
              backgroundColor: AppTheme.warningColor,
            ),
          );
        }
        return false;
      }

      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذر التحقق من شروط الحساب: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
      return false;
    }
  }

  Future<void> _calculateResults(String roundId) async {
    try {
      // Vérifier les préconditions de la version
      final allowed = await _checkCalculationAllowed();
      if (!allowed) return;

      // Afficher un dialog de chargement
      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => AlertDialog(
              backgroundColor: AppTheme.backgroundColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusL),
              ),
              content: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppTheme.primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingS),
                  Text(
                    'جاري حساب النتائج...',
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.textPrimaryColor,
                    ),
                  ),
                ],
              ),
            ),
      );

      await _resultsService.calculateRoundResults(roundId);

      // Fermer le dialog
      if (mounted) Navigator.of(context).pop();

      // Afficher un message de succès
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: AppTheme.spacingS),
                const Text('تم حساب النتائج بنجاح'),
              ],
            ),
            backgroundColor: AppTheme.successColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusS),
            ),
          ),
        );
      }

      // Recharger les rounds pour mettre à jour l'état
      _loadRounds();
    } catch (e) {
      // Fermer le dialog
      if (mounted) Navigator.of(context).pop();

      // Afficher l'erreur
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_rounded, color: Colors.white),
                const SizedBox(width: AppTheme.spacingS),
                Expanded(child: Text('خطأ: ${e.toString()}')),
              ],
            ),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusS),
            ),
          ),
        );
      }
    }
  }

  // Bouton de publication supprimé dans cette page (publication depuis صفحة النتائج التفصيلية)

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('نتائج ${widget.version.name}')),
      body:
          _isLoading
              ? const ModernLoadingIndicator()
              : _error != null
              ? Center(
                child: SingleChildScrollView(
                  child: EmptyState(
                    icon: Icons.wifi_off_rounded,
                    iconColor: AppTheme.errorColor,
                    title: 'تعذر تحميل الجولات',
                    subtitle: 'تحقق من الاتصال وحاول مجدداً',
                    action: PrimaryButton(
                      text: 'إعادة المحاولة',
                      icon: Icons.refresh_rounded,
                      onPressed: _loadRounds,
                    ),
                  ),
                ),
              )
              : _rounds.isEmpty
              ? const EmptyState(
                icon: Icons.event_busy_rounded,
                title: 'لا توجد جولات',
                subtitle: 'لم يتم إنشاء أي جولات لهذه النسخة بعد',
              )
              : ModernPullToRefresh(
                onRefresh: _loadRounds,
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(AppTheme.spacingM),
                  itemCount: _rounds.length,
                  separatorBuilder:
                      (_, __) => const SizedBox(height: AppTheme.spacingM),
                  itemBuilder:
                      (context, index) => _buildRoundCard(_rounds[index]),
                ),
              ),
    );
  }

  Widget _buildRoundCard(Round round) {
    final published = round.resultIsPublished;

    return AppSection(
      icon: Icons.flag_rounded,
      color: published ? AppTheme.successColor : AppTheme.primaryColor,
      title: round.name ?? 'الجولة ${round.number}',
      subtitle: 'الجولة رقم ${round.number}',
      trailing: AppTag(
        text: published ? 'النتائج منشورة' : 'غير منشورة',
        color: published ? AppTheme.successColor : AppTheme.warningColor,
        icon: published ? Icons.public_rounded : Icons.public_off_rounded,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (round.startDate != null || round.endDate != null) ...[
            Wrap(
              spacing: AppTheme.spacingXS,
              runSpacing: AppTheme.spacingXS,
              children: [
                if (round.startDate != null)
                  AppTag(
                    text: 'من ${_formatDate(round.startDate!)}',
                    color: AppTheme.textSecondaryColor,
                    icon: Icons.calendar_today_rounded,
                  ),
                if (round.endDate != null)
                  AppTag(
                    text: 'إلى ${_formatDate(round.endDate!)}',
                    color: AppTheme.textSecondaryColor,
                    icon: Icons.event_rounded,
                  ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingM),
          ],
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed:
                      published ? null : () => _calculateResults(round.id),
                  style: AppButtonStyles.filled(AppTheme.primaryColor),
                  icon: const Icon(Icons.calculate_rounded, size: 18),
                  label: const FittedBox(child: Text('حساب النتائج')),
                ),
              ),
              const SizedBox(width: AppTheme.spacingS),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      () => context.push(
                        '/admin/version_result/${round.id}',
                        extra: {'version': widget.version, 'round': round},
                      ),
                  style: AppButtonStyles.outlined(AppTheme.primaryColor),
                  icon: const Icon(Icons.visibility_rounded, size: 18),
                  label: const FittedBox(child: Text('عرض النتائج')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
