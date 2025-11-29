import 'package:flutter/material.dart';
import 'package:quranic_competition/core/services/user_service.dart';
import 'package:quranic_competition/core/services/round_jury_service.dart';
import 'package:quranic_competition/core/services/evaluation_service.dart';
import 'package:quranic_competition/core/services/push_notification_service.dart';
import 'package:quranic_competition/models/app_user.dart';
import 'package:quranic_competition/models/competition_version.dart';
import 'package:quranic_competition/models/round.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import '../../../../core/widgets/modern_navigation.dart';
import '../../../../core/widgets/ui_components.dart';
import '../../../../core/widgets/loading_states.dart';
import '../../../../core/theme/app_theme.dart';
import 'package:excel/excel.dart' as xls;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:typed_data';

class AllRoundsJurysPage extends StatefulWidget {
  final CompetitionVersion version;

  const AllRoundsJurysPage({super.key, required this.version});

  @override
  State<AllRoundsJurysPage> createState() => _AllRoundsJurysPageState();
}

class _AllRoundsJurysPageState extends State<AllRoundsJurysPage> {
  final UserService _userService = UserService();
  final RoundJuryService _roundJuryService = RoundJuryService();
  final EvaluationService _evaluationService = EvaluationService();
  final PushNotificationService _pushNotificationService =
      PushNotificationService();

  Map<String, List<AppUser>> _jurysByRound = {};
  List<Round> _rounds = [];
  bool _isLoading = true;
  bool _isCheckingEvaluations = false;
  Map<String, Map<String, bool>> _juryEvaluationStatus =
      {}; // roundId -> juryId -> hasCompletedAll
  Map<String, bool> _isExporting = {}; // juryId+roundId -> isExporting

  @override
  void initState() {
    super.initState();
    _loadRoundsAndJurys();
  }

  Future<void> _loadRoundsAndJurys() async {
    print(
      '🔄 Chargement des rounds et jurys pour la version: ${widget.version.id}',
    );
    setState(() => _isLoading = true);

    try {
      // 1. Charger les rounds de la version
      final roundsResponse = await Supabase.instance.client
          .from('rounds')
          .select()
          .eq('version_id', widget.version.id)
          .order('number', ascending: true);

      _rounds = roundsResponse.map<Round>((r) => Round.fromMap(r)).toList();
      print('✅ ${_rounds.length} rounds récupérés');

      // 2. Charger les jurys pour chaque round
      _jurysByRound.clear();
      _juryEvaluationStatus.clear();
      for (final round in _rounds) {
        final jurys = await _roundJuryService.getJurysByRound(round.id);
        _jurysByRound[round.id] = jurys;
        print('🎯 Round ${round.number}: ${jurys.length} jurys');

        // Vérifier l'état des évaluations pour chaque jury
        for (final jury in jurys) {
          // Vérifier d'abord si le jury a des évaluations
          final supabase = Supabase.instance.client;
          final evaluationsList = await supabase
              .from('evaluations')
              .select('id')
              .eq('jury_id', jury.id)
              .eq('round_id', round.id);

          bool hasCompleted = false;
          if (evaluationsList.isNotEmpty) {
            // Vérifier si toutes les évaluations sont terminées
            hasCompleted = await _checkJuryHasEvaluatedAllForRound(
              jury.id,
              round.id,
            );
          }
          // Si le jury n'a pas d'évaluations, hasCompleted reste false

          if (_juryEvaluationStatus[round.id] == null) {
            _juryEvaluationStatus[round.id] = {};
          }
          _juryEvaluationStatus[round.id]![jury.id] = hasCompleted;
        }
      }

      if (!mounted) return;
      setState(() => _isLoading = false);
    } catch (e) {
      print('❌ Erreur lors du chargement: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطأ أثناء تحميل البيانات: $e')));
    }
  }

  Future<void> _showAddJurySheet(Round round) async {
    print(
      '📋 Affichage de la feuille d\'ajout de jury pour le round ${round.number}',
    );

    // Vérifier si l'évaluation des jurys est activée
    if (widget.version.juryEvaluationEnabled) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('لا يمكن إضافة محكمين أثناء تفعيل التقييم'),
          backgroundColor: AppTheme.warningColor,
        ),
      );
      return;
    }

    try {
      // Récupérer tous les utilisateurs avec le rôle "jury"
      final allJurys = await _userService.getAllJurys();
      final juryOnly =
          allJurys
              .where(
                (jury) =>
                    (jury.role.trim().toLowerCase() == 'jury' ||
                        jury.role.trim().toLowerCase().contains('jury')) &&
                    jury.isVerified ==
                        true, // Filtrer seulement les jurys validés
              )
              .toList();

      // Filtrer les jurys déjà assignés à ce round
      final assignedJuryIds =
          _jurysByRound[round.id]?.map((j) => j.id).toSet() ?? {};
      final availableJurys =
          juryOnly.where((j) => !assignedJuryIds.contains(j.id)).toList();

      if (availableJurys.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('كل المحكمين مسجلين بالفعل لهذه الجولة'),
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
        builder: (context) => _buildAddJurySheet(round, availableJurys),
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

  Widget _buildAddJurySheet(Round round, List<AppUser> availableJurys) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.textSecondaryColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(Icons.person_add, color: AppTheme.primaryColor, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'إضافة مصحح للجولة ${round.number}',
                    style: AppTheme.headingMedium.copyWith(
                      color: AppTheme.textPrimaryColor,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: AppTheme.textSecondaryColor),
                ),
              ],
            ),
          ),

          // List of available jurys
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: availableJurys.length,
              itemBuilder: (context, index) {
                final jury = availableJurys[index];
                return ModernCard(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                      child: Icon(Icons.person, color: AppTheme.primaryColor),
                    ),
                    title: Text(
                      jury.fullName,
                      style: AppTheme.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimaryColor,
                      ),
                    ),
                    subtitle: Text(
                      jury.phone,
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                    trailing: ElevatedButton(
                      onPressed: () => _addJuryToRound(round, jury),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('إضافة'),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addJuryToRound(Round round, AppUser jury) async {
    try {
      print('➕ Ajout du jury ${jury.fullName} au round ${round.number}');

      final success = await _roundJuryService.assignJuryToRound(
        jury.id,
        round.id,
      );

      if (success) {
        if (!mounted) return;
        Navigator.pop(context);

        // Recharger la liste des jurys pour ce round
        await _refreshRoundJurys(round.id);

        // Envoyer une notification au jury
        try {
          final roundName = round.name ?? 'الجولة ${round.number}';
          final payload = jsonEncode({
            'type': 'jury_assigned_to_round',
            'round_id': round.id,
            'round_name': roundName,
            'round_number': round.number,
            'version_id': widget.version.id,
            'version_name': widget.version.name,
          });

          await _pushNotificationService.sendNotification(
            title: 'تم تعيينك كمصحح',
            body:
                'تم تعيينك كمصحح للجولة ${round.number} في النسخة "${widget.version.name}". يمكنك الآن البدء في التقييم.',
            type: 'info',
            payload: payload,
            userId: jury.id,
          );

          print('✅ Notification envoyée au jury ${jury.fullName}');
        } catch (e) {
          print('⚠️ Erreur lors de l\'envoi de la notification au jury: $e');
          // Ne pas bloquer le succès de l'ajout si la notification échoue
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم إضافة ${jury.fullName} بنجاح للجولة ${round.number}',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل في إضافة المصحح'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('❌ Erreur lors de l\'ajout du jury: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ أثناء إضافة المصحح: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _refreshRoundJurys(String roundId) async {
    try {
      final jurys = await _roundJuryService.getJurysByRound(roundId);
      setState(() {
        _jurysByRound[roundId] = jurys;
      });
    } catch (e) {
      print('❌ Erreur lors du rechargement des jurys: $e');
    }
  }

  Future<void> _removeJuryFromRound(Round round, AppUser jury) async {
    print(
      '🗑️ Demande de suppression du jury: ${jury.fullName} du round ${round.number}',
    );

    // Vérifier si l'évaluation des jurys est activée
    if (widget.version.juryEvaluationEnabled) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('لا يمكن حذف محكمين أثناء تفعيل التقييم'),
          backgroundColor: AppTheme.warningColor,
        ),
      );
      return;
    }

    try {
      // Afficher le loading pendant la vérification
      setState(() => _isCheckingEvaluations = true);

      // Vérifier d'abord si le jury a des évaluations pour ce round
      final supabase = Supabase.instance.client;
      final evaluationsList = await supabase
          .from('evaluations')
          .select('id')
          .eq('jury_id', jury.id)
          .eq('round_id', round.id);

      final hasEvaluations = evaluationsList.isNotEmpty;
      print('🔍 Jury a ${evaluationsList.length} évaluations pour ce round');

      String message;
      String confirmText;
      bool hasEvaluatedAll = false;

      if (hasEvaluations) {
        // Vérifier si le jury a évalué tous les participants pour ce round
        print('🔍 Vérification si le jury a évalué tous les participants...');
        hasEvaluatedAll = await _checkJuryHasEvaluatedAllForRound(
          jury.id,
          round.id,
        );

        if (hasEvaluatedAll) {
          message =
              'سيتم حذف المحكم فقط، وسيتم الاحتفاظ بتقييماته لأنها مكتملة';
          confirmText = 'حذف المحكم (الاحتفاظ بالتقييمات)';
        } else {
          message = 'سيتم حذف المحكم وجميع تقييماته في هذه الجولة';
          confirmText = 'حذف المحكم والتقييمات';
        }
      } else {
        // Le jury n'a aucune évaluation pour ce round
        message = 'سيتم حذف المحكم من هذه الجولة (لا توجد تقييمات)';
        confirmText = 'حذف المحكم';
        hasEvaluatedAll = false;
      }

      // Masquer le loading
      setState(() => _isCheckingEvaluations = false);

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
                    'هل تريد حذف ${jury.fullName} من الجولة ${round.number}؟',
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

      // Vérifier à nouveau si le jury a des évaluations
      final evaluationsCheck = await supabase
          .from('evaluations')
          .select('id')
          .eq('jury_id', jury.id)
          .eq('round_id', round.id);

      final hasEvaluationsForDeletion = evaluationsCheck.isNotEmpty;

      if (hasEvaluatedAll && hasEvaluationsForDeletion) {
        // Le jury a évalué tous les participants : supprimer seulement l'assignation
        print(
          '✅ Jury a évalué tous les participants - suppression de l\'assignation seulement',
        );
        await _roundJuryService.removeJuryFromRound(jury.id, round.id);
      } else {
        // Le jury n'a pas évalué tous les participants OU n'a pas d'évaluations : supprimer assignation + évaluations
        if (hasEvaluationsForDeletion) {
          print(
            '⚠️ Jury n\'a pas évalué tous les participants - suppression des évaluations',
          );
        } else {
          print(
            'ℹ️ Jury n\'a pas d\'évaluations - suppression de l\'assignation seulement',
          );
        }

        // 1. Supprimer toutes les évaluations du jury pour ce round (si elles existent)
        if (hasEvaluationsForDeletion) {
          await _evaluationService.deleteEvaluationsByJuryInVersion(
            juryId: jury.id,
            versionId: widget.version.id,
          );
        }

        // 2. Supprimer l'assignation du jury
        await _roundJuryService.removeJuryFromRound(jury.id, round.id);
      }

      // Recharger la liste des jurys pour ce round
      await _refreshRoundJurys(round.id);

      // Re-vérifier l'état des évaluations pour ce jury
      final finalEvaluationsCheck = await supabase
          .from('evaluations')
          .select('id')
          .eq('jury_id', jury.id)
          .eq('round_id', round.id);

      bool hasCompleted = false;
      if (finalEvaluationsCheck.isNotEmpty) {
        hasCompleted = await _checkJuryHasEvaluatedAllForRound(
          jury.id,
          round.id,
        );
      }

      if (_juryEvaluationStatus[round.id] == null) {
        _juryEvaluationStatus[round.id] = {};
      }
      _juryEvaluationStatus[round.id]![jury.id] = hasCompleted;

      if (!mounted) return;

      // Déterminer le message de succès approprié
      String successMessage;
      final hadEvaluations = finalEvaluationsCheck.isNotEmpty;

      if (!hadEvaluations) {
        successMessage =
            '${jury.fullName} تم حذفه بنجاح من الجولة ${round.number}';
      } else if (hasEvaluatedAll) {
        successMessage =
            '${jury.fullName} تم حذفه بنجاح (تم الاحتفاظ بتقييماته)';
      } else {
        successMessage = '${jury.fullName} تم حذفه بنجاح مع جميع تقييماته';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(successMessage),
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

  /// Vérifie si un jury a évalué tous les participants éligibles pour un round spécifique
  /// Round 1: participants avec is_accepted = true
  /// Round 2+: participants avec is_accepted = true ET passed_round1 = true
  Future<bool> _checkJuryHasEvaluatedAllForRound(
    String juryId,
    String roundId,
  ) async {
    try {
      print(
        '🔍 Vérification des évaluations du jury $juryId pour le round $roundId',
      );
      print('🔍 Version ID: ${widget.version.id}');

      final supabase = Supabase.instance.client;

      // 1. Récupérer tous les participants acceptés selon le round
      List<Map<String, dynamic>> participantsResponse;

      if (roundId == _getRoundIdByNumber(1)) {
        // Round 1: tous les participants acceptés
        participantsResponse = await supabase
            .from('participants')
            .select('id')
            .eq('is_accepted', true);
        print('🎯 Round 1: Tous les participants acceptés');
      } else {
        // Round 2+: participants acceptés ET qui ont passé le round 1
        participantsResponse = await supabase
            .from('participants')
            .select('id')
            .eq('is_accepted', true)
            .eq('passed_round1', true);
        print('🎯 Round 2+: Participants acceptés ET passed_round1 = true');
      }

      if (participantsResponse.isEmpty) {
        print('✅ Aucun participant accepté - pas d\'évaluations nécessaires');
        return true; // Pas de participants = pas d'évaluations nécessaires
      }

      final acceptedParticipants =
          participantsResponse.map<String>((p) => p['id'] as String).toSet();

      print(
        '👥 ${acceptedParticipants.length} participants éligibles trouvés pour ce round',
      );

      // 2. Récupérer les évaluations du jury pour ce round
      final evaluationsResponse = await supabase
          .from('evaluations')
          .select('participant_id')
          .eq('jury_id', juryId)
          .eq('round_id', roundId);

      print(
        '🔍 ${evaluationsResponse.length} évaluations trouvées pour ce jury dans ce round',
      );

      final evaluatedParticipants =
          evaluationsResponse
              .map<String>((e) => e['participant_id'] as String)
              .toSet();

      print(
        '📝 ${evaluatedParticipants.length} participants évalués par ce jury dans ce round',
      );

      // 3. Vérifier que tous les participants éligibles ont été évalués par ce jury
      final hasEvaluatedAll = acceptedParticipants.every(
        (participantId) => evaluatedParticipants.contains(participantId),
      );

      if (hasEvaluatedAll) {
        print('✅ Jury a évalué tous les participants acceptés pour ce round');
      } else {
        print(
          '❌ Jury n\'a pas évalué tous les participants acceptés pour ce round',
        );
        final missing = acceptedParticipants.difference(evaluatedParticipants);
        print('👥 Participants manquants: ${missing.length}');
        print('👥 IDs manquants: ${missing.toList()}');
      }

      return hasEvaluatedAll;
    } catch (e) {
      print('❌ Erreur lors de la vérification des évaluations du jury: $e');
      // En cas d'erreur, on considère que le jury n'a pas évalué tous les participants
      // pour éviter de perdre des évaluations par erreur
      return false;
    }
  }

  /// Récupère l'ID du round par son numéro
  String? _getRoundIdByNumber(int roundNumber) {
    try {
      final round = _rounds.firstWhere((r) => r.number == roundNumber);
      return round.id;
    } catch (e) {
      print('❌ Round $roundNumber non trouvé');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: ModernAppBar(title: 'إدارة المصححين - ${widget.version.name}'),
      body: _isLoading ? _buildLoadingState() : _buildContent(),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
          ),
          const SizedBox(height: 16),
          Text(
            'جاري التحميل...',
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.textSecondaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_rounds.isEmpty) {
      return Center(
        child: EmptyState(
          icon: Icons.event_busy,
          title: 'لا توجد جولات',
          subtitle: 'لم يتم إنشاء أي جولات لهذه النسخة بعد',
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _rounds.length,
      itemBuilder: (context, index) {
        final round = _rounds[index];
        final jurys = _jurysByRound[round.id] ?? [];

        return _buildRoundCard(round, jurys);
      },
    );
  }

  Widget _buildRoundCard(Round round, List<AppUser> jurys) {
    return ModernCard(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header du round
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.event, color: Colors.white, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    round.name != null ? ' - ${round.name}' : '',
                    style: AppTheme.headingMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // Container(
                //   padding: const EdgeInsets.symmetric(
                //     horizontal: 8,
                //     vertical: 4,
                //   ),
                //   decoration: BoxDecoration(
                //     color: Colors.white.withOpacity(0.2),
                //     borderRadius: BorderRadius.circular(12),
                //   ),
                //   child: Text(
                //     '${jurys.length} مصحح',
                //     style: AppTheme.bodySmall.copyWith(
                //       color: Colors.white,
                //       fontWeight: FontWeight.w600,
                //     ),
                //   ),
                // ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _showAddJurySheet(round),
                  icon: const Icon(Icons.person_add, color: Colors.white),
                  tooltip: 'إضافة مصحح',
                ),
              ],
            ),
          ),

          // Liste des jurys
          if (jurys.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.people_outline,
                      size: 48,
                      color: AppTheme.textSecondaryColor,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'لا يوجد مصححون لهذه الجولة',
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: jurys.length,
              itemBuilder: (context, index) {
                final jury = jurys[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                    child: Text(
                      '${index + 1}',
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    jury.fullName,
                    style: AppTheme.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimaryColor,
                    ),
                  ),
                  subtitle: Text(
                    jury.phone,
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textSecondaryColor,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Bouton d'exportation si toutes les évaluations sont terminées
                      if (_juryEvaluationStatus[round.id]?[jury.id] == true)
                        _isExporting['${jury.id}_${round.id}'] == true
                            ? Container(
                              width: 24,
                              height: 24,
                              padding: const EdgeInsets.all(4),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppTheme.infoColor,
                                ),
                              ),
                            )
                            : IconButton(
                              onPressed:
                                  () => _exportJuryEvaluations(round, jury),
                              icon: Icon(
                                Icons.file_download,
                                color: AppTheme.infoColor,
                              ),
                              tooltip: 'تصدير التصحيحات',
                            ),
                      const SizedBox(width: 8),
                      // Bouton de suppression
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
                            onPressed: () => _removeJuryFromRound(round, jury),
                            icon: Icon(Icons.delete_outline, color: Colors.red),
                            tooltip: 'إزالة من الجولة',
                          ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Future<void> _exportJuryEvaluations(Round round, AppUser jury) async {
    final key = '${jury.id}_${round.id}';
    if (_isExporting[key] == true) return;

    setState(() {
      _isExporting[key] = true;
    });

    try {
      // Récupérer les évaluations du jury pour ce round avec les informations des participants
      final evaluationsResponse = await Supabase.instance.client
          .from('evaluations')
          .select('''
            *,
            participants(
              id,
              registration_number,
              full_name,
              gender,
              age_group
            )
          ''')
          .eq('jury_id', jury.id)
          .eq('round_id', round.id);

      if (evaluationsResponse.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('لا توجد تصحيحات لتصديرها'),
            backgroundColor: AppTheme.warningColor,
          ),
        );
        return;
      }

      // Préparer les données pour l'exportation
      final List<Map<String, dynamic>> evaluationsData = [];

      for (final eval in evaluationsResponse) {
        final participant = eval['participants'];
        final ageGroup = participant['age_group'] as String;
        final notesJson = eval['notes_json'] as Map<String, dynamic>? ?? {};

        evaluationsData.add({
          'registration_number': participant['registration_number'],
          'full_name': participant['full_name'],
          'gender': participant['gender'],
          'age_group': ageGroup,
          'total_score': eval['total_score'],
          'notes': eval['notes'],
          'submitted_at': eval['submitted_at'],
          'notes_json': notesJson,
        });
      }

      // Créer le fichier Excel
      final xls.Excel excel = xls.Excel.createExcel();

      // Trier par groupe d'âge et score décroissant
      final adults =
          evaluationsData.where((e) => e['age_group'] == 'كبار').toList()..sort(
            (a, b) =>
                (b['total_score'] as num).compareTo(a['total_score'] as num),
          );

      final children =
          evaluationsData.where((e) => e['age_group'] == 'صغار').toList()..sort(
            (a, b) =>
                (b['total_score'] as num).compareTo(a['total_score'] as num),
          );

      // Fonction pour construire les lignes selon le groupe d'âge
      List<List<xls.CellValue?>> _buildRows(
        List<Map<String, dynamic>> list,
        String ageGroup,
      ) {
        final rows = <List<xls.CellValue?>>[];

        if (ageGroup == 'كبار') {
          rows.add([
            xls.TextCellValue('رقم التسجيل'),
            xls.TextCellValue('الاسم الكامل'),
            xls.TextCellValue('الجنس'),
            xls.TextCellValue('التجويد'),
            xls.TextCellValue('حسن الصوت'),
            xls.TextCellValue('عذوبة الصوت'),
            xls.TextCellValue('الوقف والإبتداء'),
            xls.TextCellValue('المجموع'),
            xls.TextCellValue('ملاحظات'),
            xls.TextCellValue('تاريخ التقديم'),
          ]);
        } else {
          rows.add([
            xls.TextCellValue('رقم التسجيل'),
            xls.TextCellValue('الاسم الكامل'),
            xls.TextCellValue('الجنس'),
            xls.TextCellValue('التجويد'),
            xls.TextCellValue('حسن الصوت'),
            xls.TextCellValue('الإلتزام بالرواية'),
            xls.TextCellValue('المجموع'),
            xls.TextCellValue('ملاحظات'),
            xls.TextCellValue('تاريخ التقديم'),
          ]);
        }

        for (final eval in list) {
          final notesJson = eval['notes_json'] as Map<String, dynamic>;

          if (ageGroup == 'كبار') {
            rows.add([
              xls.TextCellValue((eval['registration_number'] ?? '').toString()),
              xls.TextCellValue(eval['full_name'] as String),
              xls.TextCellValue(eval['gender'] as String),
              xls.DoubleCellValue(
                (notesJson['التجويد'] as num?)?.toDouble() ?? 0.0,
              ),
              xls.DoubleCellValue(
                (notesJson['حسن الصوت'] as num?)?.toDouble() ?? 0.0,
              ),
              xls.DoubleCellValue(
                (notesJson['عذوبة الصوت'] as num?)?.toDouble() ?? 0.0,
              ),
              xls.DoubleCellValue(
                (notesJson['الوقف والإبتداء'] as num?)?.toDouble() ?? 0.0,
              ),
              xls.DoubleCellValue((eval['total_score'] as num).toDouble()),
              xls.TextCellValue(eval['notes'] as String? ?? ''),
              xls.TextCellValue(eval['submitted_at'] as String),
            ]);
          } else {
            rows.add([
              xls.TextCellValue((eval['registration_number'] ?? '').toString()),
              xls.TextCellValue(eval['full_name'] as String),
              xls.TextCellValue(eval['gender'] as String),
              xls.DoubleCellValue(
                (notesJson['التجويد'] as num?)?.toDouble() ?? 0.0,
              ),
              xls.DoubleCellValue(
                (notesJson['حسن الصوت'] as num?)?.toDouble() ?? 0.0,
              ),
              xls.DoubleCellValue(
                (notesJson['الإلتزام بالرواية'] as num?)?.toDouble() ?? 0.0,
              ),
              xls.DoubleCellValue((eval['total_score'] as num).toDouble()),
              xls.TextCellValue(eval['notes'] as String? ?? ''),
              xls.TextCellValue(eval['submitted_at'] as String),
            ]);
          }
        }
        return rows;
      }

      void _addSheet(
        String name,
        List<Map<String, dynamic>> list,
        String ageGroup,
      ) {
        final sheet = excel[name];
        final rows = _buildRows(list, ageGroup);
        for (final row in rows) {
          sheet.appendRow(row);
        }
      }

      // Remplir les feuilles
      if (adults.isNotEmpty) {
        _addSheet('الكبار', adults, 'كبار');
      }
      if (children.isNotEmpty) {
        _addSheet('الصغار', children, 'صغار');
      }

      // Supprimer la feuille par défaut vide (Sheet1)
      try {
        final defaultSheet = excel.getDefaultSheet();
        if (defaultSheet != null) {
          excel.delete(defaultSheet);
        }
      } catch (e) {
        debugPrint('Note: Impossible de supprimer la feuille par défaut: $e');
      }

      // Nom de fichier significatif بالعربية
      final roundName = round.name ?? 'الجولة_${round.number}';
      final versionName = widget.version.name.trim();
      final fileName =
          'تصحيحات_${jury.fullName}_${roundName}_${versionName}_${widget.version.year}.xlsx';

      final bytes = excel.save();
      if (bytes == null) {
        throw Exception('فشل توليد الملف');
      }

      // تحويل List<int> إلى Uint8List للمشاركة والحفظ
      final uint8Bytes = Uint8List.fromList(bytes);

      // حفظ مؤقت للسماح بالمشاركة
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$fileName');
      await tempFile.writeAsBytes(uint8Bytes, flush: true);

      if (!mounted) return;

      // عرض خيارات للمستخدم: حفظ أو مشاركة
      final action = await showDialog<String>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('اختر الإجراء', style: AppTheme.headingSmall),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ما الذي تريد فعله بالملف؟', style: AppTheme.bodyMedium),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop('save'),
                child: Text(
                  'حفظ في الملفات',
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop('share'),
                child: Text(
                  'مشاركة',
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ],
          );
        },
      );

      if (action == 'save') {
        // السماح للمستخدم باختيار موقع الحفظ
        try {
          final String? savePath = await FilePicker.platform.saveFile(
            dialogTitle: 'اختر موقع الحفظ',
            fileName: fileName,
            type: FileType.custom,
            allowedExtensions: ['xlsx'],
            bytes: uint8Bytes,
          );

          if (savePath != null) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('تم حفظ الملف بنجاح'),
                backgroundColor: AppTheme.successColor,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('خطأ في حفظ الملف: $e'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      } else if (action == 'share') {
        // مشاركة الملف
        await Share.shareXFiles(
          [XFile(tempFile.path)],
          text:
              'تصحيحات ${jury.fullName} - ${roundName} - ${versionName} ${widget.version.year}',
          subject: 'تصحيحات ${jury.fullName}',
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر تصدير التصحيحات: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isExporting[key] = false;
        });
      }
    }
  }
}
