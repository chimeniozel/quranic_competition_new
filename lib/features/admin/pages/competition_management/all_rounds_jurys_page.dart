import 'package:flutter/material.dart';
import 'package:quranic_competition/core/services/user_service.dart';
import 'package:quranic_competition/core/services/round_jury_service.dart';
import 'package:quranic_competition/core/services/evaluation_service.dart';
import 'package:quranic_competition/models/app_user.dart';
import 'package:quranic_competition/models/competition_version.dart';
import 'package:quranic_competition/models/round.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/widgets/modern_navigation.dart';
import '../../../../core/widgets/ui_components.dart';
import '../../../../core/widgets/loading_states.dart';
import '../../../../core/theme/app_theme.dart';

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

  Map<String, List<AppUser>> _jurysByRound = {};
  List<Round> _rounds = [];
  bool _isLoading = true;
  bool _isCheckingEvaluations = false;

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
      for (final round in _rounds) {
        final jurys = await _roundJuryService.getJurysByRound(round.id);
        _jurysByRound[round.id] = jurys;
        print('🎯 Round ${round.number}: ${jurys.length} jurys');
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

      // Filtrer les jurys déjà assignés à ce round
      final assignedJuryIds =
          _jurysByRound[round.id]?.map((j) => j.id).toSet() ?? {};
      final availableJurys =
          allJurys.where((j) => !assignedJuryIds.contains(j.id)).toList();

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

      // Vérifier si le jury a évalué tous les participants pour ce round
      print('🔍 Vérification si le jury a évalué tous les participants...');
      final hasEvaluatedAll = await _checkJuryHasEvaluatedAllForRound(
        jury.id,
        round.id,
      );

      // Masquer le loading
      setState(() => _isCheckingEvaluations = false);

      String message;
      String confirmText;
      if (hasEvaluatedAll) {
        message = 'سيتم حذف المحكم فقط، وسيتم الاحتفاظ بتقييماته لأنها مكتملة';
        confirmText = 'حذف المحكم (الاحتفاظ بالتقييمات)';
      } else {
        message = 'سيتم حذف المحكم وجميع تقييماته في هذه الجولة';
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

      if (hasEvaluatedAll) {
        // Le jury a évalué tous les participants : supprimer seulement l'assignation
        print(
          '✅ Jury a évalué tous les participants - suppression de l\'assignation seulement',
        );
        await _roundJuryService.removeJuryFromRound(jury.id, round.id);
      } else {
        // Le jury n'a pas évalué tous les participants : supprimer assignation + évaluations
        print(
          '⚠️ Jury n\'a pas évalué tous les participants - suppression des évaluations',
        );

        // 1. Supprimer toutes les évaluations du jury pour ce round
        await _evaluationService.deleteEvaluationsByJuryInVersion(
          juryId: jury.id,
          versionId: widget.version.id,
        );

        // 2. Supprimer l'assignation du jury
        await _roundJuryService.removeJuryFromRound(jury.id, round.id);
      }

      // Recharger la liste des jurys pour ce round
      await _refreshRoundJurys(round.id);

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
          subtitle: 'لم يتم إنشاء أي جولات لهذه المسابقة بعد',
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
                    'الجولة ${round.number}${round.name != null ? ' - ${round.name}' : ''}',
                    style: AppTheme.headingMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${jurys.length} مصحح',
                    style: AppTheme.bodySmall.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
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
                            onPressed: () => _removeJuryFromRound(round, jury),
                            icon: Icon(Icons.delete_outline, color: Colors.red),
                            tooltip: 'إزالة من الجولة',
                          ),
                );
              },
            ),
        ],
      ),
    );
  }
}
