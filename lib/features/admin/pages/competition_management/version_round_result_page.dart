import 'package:flutter/material.dart';
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
                Icon(Icons.check_circle, color: Colors.white),
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
                Icon(Icons.error, color: Colors.white),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text('نتائج ${widget.version.name}'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body:
          _isLoading
              ? const ModernLoadingIndicator()
              : _error != null
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppTheme.spacingL),
                      decoration: BoxDecoration(
                        color: AppTheme.errorColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.error_outline,
                        size: 64,
                        color: AppTheme.errorColor,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingL),
                    Text(
                      'خطأ في التحميل',
                      style: AppTheme.headingMedium.copyWith(
                        color: AppTheme.textPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingS),
                    Text(
                      '$_error',
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.textSecondaryColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppTheme.spacingL),
                    ElevatedButton.icon(
                      onPressed: _loadRounds,
                      icon: const Icon(Icons.refresh),
                      label: const Text('إعادة المحاولة'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              )
              : _rounds.isEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppTheme.spacingL),
                      decoration: BoxDecoration(
                        color: AppTheme.warningColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.event_busy,
                        size: 64,
                        color: AppTheme.warningColor,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingL),
                    Text(
                      'لا توجد جولات',
                      style: AppTheme.headingMedium.copyWith(
                        color: AppTheme.textPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingS),
                    Text(
                      'لم يتم إنشاء أي جولات لهذه النسخة بعد',
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.textSecondaryColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
              : ListView.builder(
                padding: const EdgeInsets.all(AppTheme.spacingS),
                itemCount: _rounds.length,
                itemBuilder: (context, index) {
                  final round = _rounds[index];
                  return _buildRoundCard(round);
                },
              ),
    );
  }

  Widget _buildRoundCard(Round round) {
    return ModernCard(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingS),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header du round
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingS),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppTheme.radiusM),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacingS),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(AppTheme.radiusS),
                  ),
                  child: const Icon(
                    Icons.emoji_events,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: AppTheme.spacingS),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${round.name ?? 'الجولة ${round.number}'}',
                        style: AppTheme.headingSmall.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'رقم الجولة: ${round.number}',
                        style: AppTheme.bodySmall.copyWith(
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingS,
                    vertical: AppTheme.spacingXS,
                  ),
                  decoration: BoxDecoration(
                    color:
                        round.resultIsPublished
                            ? AppTheme.successColor
                            : AppTheme.warningColor,
                    borderRadius: BorderRadius.circular(AppTheme.radiusS),
                  ),
                  child: Text(
                    round.resultIsPublished ? 'منشور' : 'غير منشور',
                    style: AppTheme.bodySmall.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Contenu du round
          Padding(
            padding: const EdgeInsets.all(AppTheme.spacingS),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (round.startDate != null)
                  _buildInfoRow(
                    Icons.calendar_today,
                    'تاريخ البداية',
                    '${round.startDate!.day}/${round.startDate!.month}/${round.startDate!.year}',
                  ),
                if (round.endDate != null)
                  _buildInfoRow(
                    Icons.event,
                    'تاريخ النهاية',
                    '${round.endDate!.day}/${round.endDate!.month}/${round.endDate!.year}',
                  ),
                const SizedBox(height: AppTheme.spacingL),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed:
                            round.resultIsPublished
                                ? null
                                : () => _calculateResults(round.id),
                        icon: const Icon(Icons.calculate),
                        label: const Text('حساب النتائج'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: AppTheme.textDisabledColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacingS),
                    const SizedBox(width: AppTheme.spacingS),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          context.push(
                            '/admin/version_result/${round.id}',
                            extra: {'version': widget.version, 'round': round},
                          );
                        },
                        icon: const Icon(Icons.visibility),
                        label: const Text('عرض النتائج'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primaryColor,
                          side: const BorderSide(color: AppTheme.primaryColor),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingS),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.textSecondaryColor),
          const SizedBox(width: AppTheme.spacingS),
          Text(
            '$label: ',
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.textSecondaryColor,
            ),
          ),
          Text(
            value,
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.textPrimaryColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
