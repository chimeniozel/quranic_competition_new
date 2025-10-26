import 'package:flutter/material.dart';
import 'package:quranic_competition/core/services/user_service.dart';
import 'package:quranic_competition/models/app_user.dart';
import 'package:quranic_competition/models/competition_version.dart';
import 'package:quranic_competition/models/evaluation.dart';
import 'package:quranic_competition/core/services/evaluation_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/widgets/modern_navigation.dart';
import '../../../../core/widgets/ui_components.dart';
import '../../../../core/widgets/loading_states.dart';
import '../../../../core/theme/app_theme.dart';

class VersionJurysPage extends StatefulWidget {
  final CompetitionVersion version;

  const VersionJurysPage({super.key, required this.version});

  @override
  State<VersionJurysPage> createState() => _VersionJurysPageState();
}

class _VersionJurysPageState extends State<VersionJurysPage> {
  final UserService _userService = UserService();
  final EvaluationService _evaluationService = EvaluationService();

  List<AppUser> _jurys = [];
  bool _isLoading = true;
  bool _isCheckingEvaluations = false;

  @override
  void initState() {
    super.initState();
    _loadJurysAndEvaluations();
  }

  Future<void> _loadJurysAndEvaluations() async {
    print('🔄 Chargement des jurys pour la version: ${widget.version.id}');
    setState(() => _isLoading = true);

    try {
      print('📡 Appel de getJurysByVersion...');
      final jurys = await _userService.getJurysByVersion(widget.version.id);
      print('✅ ${jurys.length} jurys récupérés');

      for (int i = 0; i < jurys.length; i++) {
        print('👤 Jury ${i + 1}: ${jurys[i].fullName} (ID: ${jurys[i].id})');
      }

      if (!mounted) return;
      setState(() {
        _jurys = jurys;
      });

      print('✅ État mis à jour: ${_jurys.length} jurys affichés');
    } catch (e) {
      print('❌ Erreur lors du chargement des jurys: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطأ أثناء التحميل: $e')));
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showAddJurySheet() async {
    print('📋 Affichage de la feuille d\'ajout de jury');

    // Vérifier si l'évaluation des jurys est activée
    if (widget.version.juryEvaluationEnabled) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("لا يمكن إضافة محكمين أثناء تفعيل التقييم"),
          backgroundColor: AppTheme.warningColor,
        ),
      );
      return;
    }

    try {
      final allJurys = await _userService.getAllJurys();
      print('👥 ${allJurys.length} jurys disponibles au total');

      final assignedIds = _jurys.map((j) => j.id).toSet();
      final availableJurys =
          allJurys.where((j) => !assignedIds.contains(j.id)).toList();

      print('✅ ${availableJurys.length} jurys disponibles pour assignation');

      if (availableJurys.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("كل المحكمين مسجلين بالفعل"),
            backgroundColor: AppTheme.warningColor,
          ),
        );
        return;
      }

      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) {
          return Container(
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppTheme.radiusXL),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.symmetric(
                    vertical: AppTheme.spacingS,
                  ),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.dividerColor,
                    borderRadius: BorderRadius.circular(AppTheme.radiusS),
                  ),
                ),

                // Header
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacingM),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppTheme.spacingS),
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          borderRadius: BorderRadius.circular(AppTheme.radiusM),
                        ),
                        child: const Icon(
                          Icons.person_add,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: AppTheme.spacingM),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'إضافة محكم',
                              style: AppTheme.labelLarge.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'اختر محكم لإضافته إلى هذه النسخة',
                              style: AppTheme.bodySmall.copyWith(
                                color: AppTheme.textSecondaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),

                // Liste des jurys disponibles
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: availableJurys.length,
                    itemBuilder: (context, index) {
                      final jury = availableJurys[index];
                      return Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spacingM,
                          vertical: AppTheme.spacingXS,
                        ),
                        child: ModernCard(
                          child: ListTile(
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                gradient: AppTheme.primaryGradient,
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radiusM,
                                ),
                              ),
                              child: const Icon(
                                Icons.person,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              jury.fullName,
                              style: AppTheme.labelMedium.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 2),
                                Text(
                                  jury.phone,
                                  style: AppTheme.bodySmall.copyWith(
                                    color: AppTheme.textSecondaryColor,
                                  ),
                                ),
                              ],
                            ),
                            trailing: PrimaryButton(
                              onPressed: () async {
                                Navigator.pop(ctx);
                                await _assignJury(jury);
                              },
                              text: 'إضافة',
                              icon: Icons.add,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Padding pour le safe area
                SizedBox(height: MediaQuery.of(context).padding.bottom),
              ],
            ),
          );
        },
      );
    } catch (e) {
      print('❌ Erreur lors de l\'affichage de la feuille d\'ajout: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ أثناء تحميل المحكمين: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  Future<void> _assignJury(AppUser jury) async {
    try {
      print('➕ Assignation du jury: ${jury.fullName}');

      await _userService.assignJuryToVersion(
        userId: jury.id,
        versionId: widget.version.id,
      );

      await _loadJurysAndEvaluations();

      // Forcer le recalcul des résultats après l'ajout d'un nouveau jury
      await _forceRecalculateResults();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${jury.fullName} أضيف بنجاح'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    } catch (e) {
      print('❌ Erreur lors de l\'assignation du jury: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل في إضافة المحكم: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  Future<void> _removeJury(AppUser jury) async {
    print('🗑️ Demande de suppression du jury: ${jury.fullName}');

    // Vérifier si l'évaluation des jurys est activée
    if (widget.version.juryEvaluationEnabled) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("لا يمكن حذف محكمين أثناء تفعيل التقييم"),
          backgroundColor: AppTheme.warningColor,
        ),
      );
      return;
    }

    try {
      // Afficher le loading pendant la vérification
      setState(() => _isCheckingEvaluations = true);

      // Vérifier si le jury a évalué tous les participants
      print('🔍 Vérification si le jury a évalué tous les participants...');
      final hasEvaluatedAll = await _checkJuryHasEvaluatedAll(jury.id);

      // Masquer le loading
      setState(() => _isCheckingEvaluations = false);

      String message;
      String confirmText;
      if (hasEvaluatedAll) {
        message = 'سيتم حذف المحكم فقط، وسيتم الاحتفاظ بتقييماته لأنها مكتملة';
        confirmText = 'حذف المحكم (الاحتفاظ بالتقييمات)';
      } else {
        message = 'سيتم حذف المحكم وجميع تقييماته في هذه النسخة';
        confirmText = 'حذف المحكم والتقييمات';
      }

      final confirm = await showDialog<bool>(
        context: context,
        builder:
            (ctx) => AlertDialog(
              title: Row(
                children: [
                  Icon(
                    Icons.warning_outlined,
                    color: AppTheme.warningColor,
                    size: 24,
                  ),
                  const SizedBox(width: AppTheme.spacingS),
                  const Text('تأكيد الحذف'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'هل تريد حذف ${jury.fullName}؟',
                    style: AppTheme.bodyLarge.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingS),
                  Container(
                    padding: const EdgeInsets.all(AppTheme.spacingS),
                    decoration: BoxDecoration(
                      color:
                          hasEvaluatedAll
                              ? AppTheme.primaryColor.withOpacity(0.1)
                              : AppTheme.warningColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radiusS),
                      border: Border.all(
                        color:
                            hasEvaluatedAll
                                ? AppTheme.primaryColor.withOpacity(0.3)
                                : AppTheme.warningColor.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          hasEvaluatedAll
                              ? Icons.check_circle_outline
                              : Icons.info_outline,
                          color:
                              hasEvaluatedAll
                                  ? AppTheme.primaryColor
                                  : AppTheme.warningColor,
                          size: 16,
                        ),
                        const SizedBox(width: AppTheme.spacingS),
                        Expanded(
                          child: Text(
                            message,
                            style: AppTheme.bodySmall.copyWith(
                              color:
                                  hasEvaluatedAll
                                      ? AppTheme.primaryColor
                                      : AppTheme.warningColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(
                    'إلغاء',
                    style: AppTheme.labelMedium.copyWith(
                      color: AppTheme.textSecondaryColor,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        hasEvaluatedAll
                            ? AppTheme.primaryColor
                            : AppTheme.errorColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusS),
                    ),
                  ),
                  child: Text(
                    confirmText,
                    style: AppTheme.labelMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
      );

      if (confirm != true) {
        print('❌ Suppression annulée par l\'utilisateur');
        return;
      }

      print('🗑️ Suppression du jury en cours...');

      if (hasEvaluatedAll) {
        // Le jury a évalué tous les participants : supprimer seulement l'assignation
        print(
          '✅ Jury a évalué tous les participants - suppression de l\'assignation seulement',
        );
        await _userService.removeJuryFromVersion(
          userId: jury.id,
          versionId: widget.version.id,
        );
      } else {
        // Le jury n'a pas évalué tous les participants : supprimer assignation + évaluations
        print(
          '⚠️ Jury n\'a pas évalué tous les participants - suppression des évaluations',
        );

        // 1. Supprimer toutes les évaluations du jury pour cette version
        await _evaluationService.deleteEvaluationsByJuryInVersion(
          juryId: jury.id,
          versionId: widget.version.id,
        );

        // 2. Supprimer l'assignation du jury
        await _userService.removeJuryFromVersion(
          userId: jury.id,
          versionId: widget.version.id,
        );
      }

      await _loadJurysAndEvaluations();

      // Forcer le recalcul des résultats après la suppression d'un jury
      await _forceRecalculateResults();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            hasEvaluatedAll
                ? '${jury.fullName} تم حذفه بنجاح (تم الاحتفاظ بتقييماته)'
                : '${jury.fullName} تم حذفه بنجاح مع جميع تقييماته',
          ),
          backgroundColor: AppTheme.successColor,
        ),
      );

      print('✅ Suppression du jury terminée avec succès');
    } catch (e) {
      print('❌ Erreur lors de la suppression du jury: $e');
      setState(() => _isCheckingEvaluations = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل في الحذف: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  /// Vérifie si un jury a évalué tous les participants acceptés pour tous les rounds où il est assigné
  Future<bool> _checkJuryHasEvaluatedAll(String juryId) async {
    try {
      print(
        '🔍 Vérification des évaluations du jury $juryId pour la version ${widget.version.id}',
      );

      final supabase = Supabase.instance.client;

      // 1. Récupérer tous les rounds où ce jury est assigné
      final roundsResponse = await supabase
          .from('rounds')
          .select('id, number')
          .eq('version_id', widget.version.id);

      if (roundsResponse.isEmpty) {
        print('⚠️ Aucun round trouvé pour cette version');
        return true; // Pas de rounds = pas d'évaluations nécessaires
      }

      final roundIds = roundsResponse.map((r) => r['id'] as String).toList();
      print('📋 ${roundIds.length} rounds trouvés pour la version');

      // 2. Vérifier que le jury est assigné à au moins un round
      final assignmentsResponse = await supabase
          .from('round_jury_assignments')
          .select('round_id')
          .eq('user_id', juryId)
          .inFilter('round_id', roundIds);

      if (assignmentsResponse.isEmpty) {
        print('⚠️ Jury non assigné à cette version');
        return true; // Pas assigné = pas d'évaluations nécessaires
      }

      final assignedRoundIds =
          assignmentsResponse.map((a) => a['round_id'] as String).toList();
      print('🎯 Jury assigné à ${assignedRoundIds.length} rounds');

      // 3. Pour chaque round assigné, vérifier que le jury a évalué tous les participants acceptés
      for (final roundId in assignedRoundIds) {
        final round = roundsResponse.firstWhere((r) => r['id'] == roundId);
        final roundNumber = round['number'];

        print('🔍 Vérification du round $roundNumber...');

        // Récupérer les participants acceptés pour ce round
        final participantsResponse = await supabase
            .from('participant_versions')
            .select('participant_id')
            .eq('version_id', widget.version.id)
            .eq('is_accepted', true);

        final acceptedParticipants =
            participantsResponse
                .map((pv) => pv['participant_id'] as String)
                .toSet();

        if (acceptedParticipants.isEmpty) {
          print('✅ Round $roundNumber: Aucun participant accepté');
          continue;
        }

        // Récupérer les évaluations du jury pour ce round
        final evaluationsResponse = await supabase
            .from('evaluations')
            .select('participant_id')
            .eq('jury_id', juryId)
            .eq('round_id', roundId);

        final evaluatedParticipants =
            evaluationsResponse
                .map((e) => e['participant_id'] as String)
                .toSet();

        print(
          '📝 Round $roundNumber: ${evaluatedParticipants.length}/${acceptedParticipants.length} participants évalués',
        );

        // Vérifier que tous les participants ont été évalués pour ce round
        final hasEvaluatedAllInRound = acceptedParticipants.every(
          (participantId) => evaluatedParticipants.contains(participantId),
        );

        if (!hasEvaluatedAllInRound) {
          print('❌ Round $roundNumber: Évaluations incomplètes');
          return false;
        }

        print('✅ Round $roundNumber: Toutes les évaluations complètes');
      }

      print('🎉 Tous les rounds assignés ont des évaluations complètes');
      return true;
    } catch (e) {
      print('❌ Erreur lors de la vérification des évaluations du jury: $e');
      // En cas d'erreur, on considère que le jury n'a pas évalué tous les participants
      // pour éviter de perdre des évaluations par erreur
      return false;
    }
  }

  /// Force le recalcul des résultats après modification des jurys
  Future<void> _forceRecalculateResults() async {
    try {
      print(
        '🔄 Forçage du recalcul des résultats après modification des jurys...',
      );

      final supabase = Supabase.instance.client;

      // Supprimer tous les résultats existants pour cette version
      await supabase
          .from('round_results')
          .delete()
          .eq('version_id', widget.version.id);

      print(
        '✅ Anciens résultats supprimés, les nouveaux seront calculés lors du prochain accès',
      );
    } catch (e) {
      print('❌ Erreur lors du forçage du recalcul: $e');
      // Ne pas afficher d'erreur à l'utilisateur car ce n'est pas critique
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ModernAppBar(
        title: 'لجنة التحكيم - ${widget.version.name}',
        actions: [
          IconButton(
            onPressed: _loadJurysAndEvaluations,
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed:
            widget.version.juryEvaluationEnabled ? null : _showAddJurySheet,
        icon: const Icon(Icons.person_add),
        label: const Text('إضافة محكم'),
        backgroundColor:
            widget.version.juryEvaluationEnabled
                ? AppTheme.textDisabledColor
                : AppTheme.primaryColor,
        foregroundColor: Colors.white,
        tooltip:
            widget.version.juryEvaluationEnabled
                ? 'التقييم مفعل - لا يمكن إضافة محكمين'
                : 'إضافة محكم جديد',
      ),
      body: Stack(
        children: [
          _isLoading
              ? const LoadingOverlay(child: SizedBox())
              : _jurys.isEmpty
              ? _buildEmptyState()
              : _buildJurysList(),
          if (_isCheckingEvaluations)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(AppTheme.spacingL),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(AppTheme.radiusM),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingM),
                      Text(
                        'جاري التحقق من التقييمات...',
                        style: AppTheme.labelMedium.copyWith(
                          color: AppTheme.textPrimaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingL),
            decoration: BoxDecoration(
              color: AppTheme.warningColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusXL),
            ),
            child: Icon(
              Icons.people_outline,
              size: 64,
              color: AppTheme.warningColor,
            ),
          ),
          const SizedBox(height: AppTheme.spacingL),
          Text(
            'لا يوجد محكمون',
            style: AppTheme.headingMedium.copyWith(
              color: AppTheme.textPrimaryColor,
            ),
          ),
          const SizedBox(height: AppTheme.spacingS),
          Text(
            'لم يتم تعيين أي محكم لهذه النسخة بعد',
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.textSecondaryColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spacingL),
          PrimaryButton(
            onPressed: _showAddJurySheet,
            text: 'إضافة محكم',
            icon: Icons.person_add,
          ),
        ],
      ),
    );
  }

  Widget _buildJurysList() {
    return ModernPullToRefresh(
      onRefresh: _loadJurysAndEvaluations,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacingS),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header avec statistiques
            ModernCard(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacingM),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppTheme.spacingS),
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(AppTheme.radiusM),
                      ),
                      child: const Icon(
                        Icons.people,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacingM),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'لجنة التحكيم',
                            style: AppTheme.labelLarge.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                '${_jurys.length} محكم مسجل',
                                style: AppTheme.bodyMedium.copyWith(
                                  color: AppTheme.textSecondaryColor,
                                ),
                              ),
                              const SizedBox(width: AppTheme.spacingS),
                            ],
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
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppTheme.radiusS),
                      ),
                      child: Text(
                        '${_jurys.length}',
                        style: AppTheme.labelLarge.copyWith(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Liste des jurys
            ...(_jurys.asMap().entries.map((entry) {
              final index = entry.key;
              final jury = entry.value;

              return _buildJuryCard(jury, [], index);
            }).toList()),
          ],
        ),
      ),
    );
  }

  Widget _buildJuryCard(AppUser jury, List<Evaluation> evaluations, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingS),
      child: ModernCard(
        child: ListTile(
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: AppTheme.labelLarge.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          title: Text(
            jury.fullName,
            style: AppTheme.labelLarge.copyWith(fontWeight: FontWeight.w600),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.phone,
                    size: 16,
                    color: AppTheme.textSecondaryColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    jury.phone,
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textSecondaryColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
          trailing:
              _isCheckingEvaluations
                  ? Container(
                    width: 24,
                    height: 24,
                    padding: const EdgeInsets.all(4),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppTheme.primaryColor,
                      ),
                    ),
                  )
                  : IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      color:
                          widget.version.juryEvaluationEnabled
                              ? AppTheme.textDisabledColor
                              : AppTheme.errorColor,
                    ),
                    tooltip:
                        widget.version.juryEvaluationEnabled
                            ? 'التقييم مفعل - لا يمكن حذف المحكم'
                            : 'حذف المحكم',
                    onPressed:
                        widget.version.juryEvaluationEnabled ||
                                _isCheckingEvaluations
                            ? null
                            : () => _removeJury(jury),
                  ),
        ),
      ),
    );
  }
}
