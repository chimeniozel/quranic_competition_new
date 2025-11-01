import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/competition_version.dart';

class CompetitionVersionService {
  final _supabase = Supabase.instance.client;

  Future<List<CompetitionVersion>> fetchVersions() async {
    final response = await _supabase
        .from('competition_versions')
        .select()
        .order('created_at', ascending: false);

    // response est List<dynamic>, on mappe correctement
    return response
        .map<CompetitionVersion>((v) => CompetitionVersion.fromMap(v))
        .toList();
  }

  /// Récupère les compétitions actives avec inscription ouverte
  Future<List<CompetitionVersion>>
  fetchActiveVersionsWithOpenRegistration() async {
    final response = await _supabase
        .from('competition_versions')
        .select()
        .eq('is_active', true)
        .eq('is_registration_open', true)
        .order('created_at', ascending: false);

    return response
        .map<CompetitionVersion>((v) => CompetitionVersion.fromMap(v))
        .toList();
  }

  /// Vérifie s'il y a au moins une compétition active avec inscription ouverte
  Future<bool> hasActiveVersionWithOpenRegistration() async {
    final activeVersions = await fetchActiveVersionsWithOpenRegistration();
    return activeVersions.isNotEmpty;
  }

  /// Écoute les changements en temps réel pour une version spécifique
  /// Utilise un Timer périodique car les streams Supabase peuvent ne pas fonctionner correctement
  Stream<Map<String, dynamic>> listenToVersionChanges(String versionId) {
    return Stream.periodic(
      const Duration(seconds: 5),
    ) // Intervalle plus court pour les tests
    .asyncMap((_) async {
      try {
        final response =
            await _supabase
                .from('competition_versions')
                .select()
                .eq('id', versionId)
                .single();
        print(
          '🔄 Vérification périodique - Version: $versionId, Registration Open: ${response['is_registration_open']}',
        );
        return response;
      } catch (e) {
        print('Erreur lors de la récupération de la version: $e');
        return <String, dynamic>{};
      }
    });
  }

  /// Écoute les changements en temps réel pour toutes les versions actives avec inscription ouverte
  /// Utilise un Timer périodique pour une vérification régulière
  Stream<List<CompetitionVersion>>
  listenToActiveVersionsWithOpenRegistration() {
    return Stream.periodic(
      const Duration(seconds: 5),
    ) // Intervalle plus court pour les tests
    .asyncMap((_) async {
      try {
        final versions = await fetchActiveVersionsWithOpenRegistration();
        print(
          '🏠 Vérification périodique - Versions actives: ${versions.length}',
        );
        return versions;
      } catch (e) {
        print('Erreur lors de la récupération des versions actives: $e');
        return <CompetitionVersion>[];
      }
    });
  }

  Future<List<CompetitionVersion>> fetchMyVersions() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      throw Exception("Utilisateur non connecté");
    }

    final userId = user.id;
    print('🔍 fetchMyVersions - User ID: $userId');

    try {
      // Étape 1: Vérifier les assignations directes
      print('🔍 Étape 1: Vérification des assignations directes...');
      final directAssignments = await _supabase
          .from('round_jury_assignments')
          .select('*')
          .eq('user_id', userId);

      print('🔍 Assignations directes trouvées: ${directAssignments.length}');
      for (final assignment in directAssignments) {
        print(
          '🔍 Assignment: user_id=${assignment['user_id']}, round_id=${assignment['round_id']}',
        );
      }

      if (directAssignments.isEmpty) {
        print('❌ Aucune assignation trouvée pour cet utilisateur');
        return [];
      }

      // Étape 2: Récupérer les rounds assignés
      print('🔍 Étape 2: Récupération des rounds assignés...');
      final roundIds =
          directAssignments.map((a) => a['round_id'] as String).toList();
      final roundsResponse = await _supabase
          .from('rounds')
          .select('*, version:competition_versions(*)')
          .inFilter('id', roundIds);

      print('🔍 Rounds trouvés: ${roundsResponse.length}');
      for (final round in roundsResponse) {
        print(
          '🔍 Round: ${round['number']}, version_id=${round['version_id']}',
        );
      }

      // Étape 3: Extraire les versions uniques
      print('🔍 Étape 3: Extraction des versions uniques...');
      final Set<String> versionIds = {};
      final List<Map<String, dynamic>> versionsData = [];

      for (final round in roundsResponse) {
        final version = round['version'];
        if (version != null) {
          final versionId = version['id'] as String;
          print('🔍 Version trouvée: ${version['name']} (ID: $versionId)');
          if (!versionIds.contains(versionId)) {
            versionIds.add(versionId);
            versionsData.add(version);
          }
        }
      }

      print(
        '🔍 fetchMyVersions - Final versions count: ${versionsData.length}',
      );
      print('🔍 fetchMyVersions - Version IDs: $versionIds');

      return versionsData
          .map((versionData) => CompetitionVersion.fromMap(versionData))
          .toList();
    } catch (e) {
      print('❌ Erreur dans fetchMyVersions: $e');
      return [];
    }
  }

  /// Méthode de test pour vérifier les données des jurys
  Future<void> debugJuryData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      print('❌ Utilisateur non connecté');
      return;
    }

    print('🔍 === DEBUG JURY DATA ===');
    print('🔍 User ID: ${user.id}');
    print('🔍 User Email: ${user.email}');

    try {
      // 1. Vérifier le profil utilisateur
      final profile =
          await _supabase
              .from('profiles')
              .select('*')
              .eq('id', user.id)
              .single();

      print('🔍 Profile: ${profile['full_name']} (Role: ${profile['role']})');

      // 2. Vérifier les assignations
      final assignments = await _supabase
          .from('round_jury_assignments')
          .select('*')
          .eq('user_id', user.id);

      print('🔍 Assignations trouvées: ${assignments.length}');
      for (final assignment in assignments) {
        print('🔍 Assignment: round_id=${assignment['round_id']}');
      }

      // 3. Vérifier tous les jurys
      final allJurys = await _supabase
          .from('profiles')
          .select('*')
          .eq('role', 'jury');

      print('🔍 Tous les jurys: ${allJurys.length}');
      for (final jury in allJurys) {
        print('🔍 Jury: ${jury['full_name']} (ID: ${jury['id']})');
      }

      // 4. Vérifier toutes les assignations
      final allAssignments = await _supabase
          .from('round_jury_assignments')
          .select('*');

      print('🔍 Toutes les assignations: ${allAssignments.length}');
      for (final assignment in allAssignments) {
        print(
          '🔍 Assignment: user_id=${assignment['user_id']}, round_id=${assignment['round_id']}',
        );
      }
    } catch (e) {
      print('❌ Erreur dans debugJuryData: $e');
    }
  }

  Future<void> createVersion({
    required String name,
    required int year,
    required int maxAdults,
    required int maxChildren,
    required bool isRegistrationOpen,
    required double successAverageAdults,
    required double successAverageChildren,
  }) async {
    final response =
        await _supabase
            .from('competition_versions')
            .insert({
              'name': name,
              'year': year,
              'max_adults': maxAdults,
              'max_children': maxChildren,
              'is_registration_open': isRegistrationOpen,
              'is_active': true,
              'jury_evaluation_enabled': false,
              'success_average_adults': successAverageAdults,
              'success_average_children': successAverageChildren,
            })
            .select()
            .single();

    final versionId = response['id'] as String;

    // Créer automatiquement 2 tours
    await _supabase.from('rounds').insert([
      {
        'version_id': versionId,
        'number': 1,
        'name': 'الجولة الأولى',
        'is_active': true,
        'result_is_published': false,
      },
      {
        'version_id': versionId,
        'number': 2,
        'name': 'الجولة النهائية',
        'is_active': false,
        'result_is_published': false,
      },
    ]);
  }

  /// Appelle la fonction stockée PostgreSQL via RPC
  Future<bool> tryAddParticipant({
    required String versionId,
    required String ageGroup,
    required String fullName,
    required String phone,
    required String password,
    String role = 'participant',
  }) async {
    final response = await _supabase.rpc(
      'add_participant_if_possible',
      params: {
        'p_version_id': versionId,
        'p_age_group': ageGroup,
        'p_full_name': fullName,
        'p_phone': phone,
        'p_password': password,
        'p_role': role,
      },
    );

    if (response.error != null) {
      throw Exception('Erreur RPC : ${response.error!.message}');
    }

    // La réponse est booléenne, en général response.data
    final success = response.data as bool? ?? false;
    return success;
  }

  /// Récupère les statistiques des éléments liés à une version
  Future<Map<String, int>> getVersionRelatedCounts(String versionId) async {
    try {
      // Compter les participants
      final participantsResponse = await _supabase
          .from('participants')
          .select('id')
          .eq('competition_id', versionId);
      final participantsCount = participantsResponse.length;

      // Compter les rounds
      final roundsResponse = await _supabase
          .from('rounds')
          .select('id')
          .eq('version_id', versionId);
      final roundsCount = roundsResponse.length;

      // Compter les évaluations (via les rounds)
      int evaluationsCount = 0;
      if (roundsCount > 0) {
        final evaluationsResponse = await _supabase
            .from('evaluations')
            .select('id')
            .inFilter('round_id', roundsResponse.map((r) => r['id']).toList());
        evaluationsCount = evaluationsResponse.length;
      }

      // Compter les assignations de jurys (via les rounds)
      int juryAssignmentsCount = 0;
      if (roundsCount > 0) {
        final juryAssignmentsResponse = await _supabase
            .from('round_jury_assignments')
            .select('user_id')
            .inFilter('round_id', roundsResponse.map((r) => r['id']).toList());
        juryAssignmentsCount = juryAssignmentsResponse.length;
      }

      // Compter les résultats
      final resultsResponse = await _supabase
          .from('round_results')
          .select('id')
          .eq('version_id', versionId);
      final resultsCount = resultsResponse.length;

      return {
        'participants': participantsCount,
        'rounds': roundsCount,
        'evaluations': evaluationsCount,
        'juryAssignments': juryAssignmentsCount,
        'results': resultsCount,
      };
    } catch (e) {
      print('Erreur lors de la récupération des statistiques: $e');
      return {
        'participants': 0,
        'rounds': 0,
        'evaluations': 0,
        'juryAssignments': 0,
        'results': 0,
      };
    }
  }

  /// Supprime une version de compétition avec suppression en cascade
  Future<void> deleteVersion(String versionId) async {
    try {
      // Vérifier d'abord si la version est active
      final versionResponse =
          await _supabase
              .from('competition_versions')
              .select('is_active, name')
              .eq('id', versionId)
              .single();

      if (versionResponse['is_active'] == true) {
        throw Exception(
          'لا يمكن حذف النسخة النشطة "${versionResponse['name']}". يجب إلغاء تفعيلها أولاً.',
        );
      }

      // Récupérer les statistiques avant suppression
      final counts = await getVersionRelatedCounts(versionId);

      print('🗑️ Suppression de la version $versionId');
      print('📊 Éléments qui seront supprimés:');
      print('   - Participants: ${counts['participants']}');
      print('   - Rounds: ${counts['rounds']}');
      print('   - Évaluations: ${counts['evaluations']}');
      print('   - Assignations jurys: ${counts['juryAssignments']}');
      print('   - Résultats: ${counts['results']}');

      // Supprimer la version (la suppression en cascade s'occupera du reste)
      final response =
          await _supabase
              .from('competition_versions')
              .delete()
              .eq('id', versionId)
              .select();

      if (response.isEmpty) {
        throw Exception('Erreur lors de la suppression : version introuvable');
      }

      print('✅ Version supprimée avec succès (suppression en cascade)');
    } catch (e) {
      print('❌ Erreur lors de la suppression de la version: $e');
      rethrow;
    }
  }

  Future<void> updateVersion({
    required String id,
    required String name,
    required int year,
    required int maxAdults,
    required int maxChildren,
    required bool isActive,
    required bool isRegistrationOpen,
    required bool juryEvaluationEnabled,
    required double successAverageAdults,
    required double successAverageChildren,
  }) async {
    final response =
        await _supabase
            .from('competition_versions')
            .update({
              'name': name,
              'year': year,
              'max_adults': maxAdults,
              'max_children': maxChildren,
              'is_active': isActive,
              'is_registration_open': isRegistrationOpen,
              'jury_evaluation_enabled': juryEvaluationEnabled,
              'success_average_adults': successAverageAdults,
              'success_average_children': successAverageChildren,
            })
            .eq('id', id)
            .select();

    // Supabase retourne une List<dynamic> quand tu fais .select()
    if (response.isEmpty) {
      throw Exception('Erreur lors de la mise à jour : version introuvable');
    }

    // Si la réponse contient une erreur (souvent dans response['error'])
    // Mais selon la version supabase_flutter, la gestion d'erreur peut être différente
    // Si tu utilises le client Dart officiel, il faut vérifier un objet Response avec 'error' dessus.
    // Ici, on suppose que la réponse est correcte si on arrive jusque là.
  }

  /// Récupère une version par son ID
  Future<CompetitionVersion?> getVersionById(String versionId) async {
    try {
      final response =
          await _supabase
              .from('competition_versions')
              .select()
              .eq('id', versionId)
              .single();

      return CompetitionVersion.fromMap(response);
    } catch (e) {
      print('Erreur lors de la récupération de la version: $e');
      return null;
    }
  }

  /// Récupère le nombre de participants par groupe d'âge pour une version
  Future<Map<String, int>> getParticipantCountsByAgeGroup(
    String versionId,
  ) async {
    try {
      // Récupérer le nombre de participants adultes pour cette version
      final adultsResponse = await _supabase
          .from('participants')
          .select('id')
          .eq('competition_id', versionId)
          .eq('age_group', 'كبار');

      // Récupérer le nombre de participants enfants pour cette version
      final childrenResponse = await _supabase
          .from('participants')
          .select('id')
          .eq('competition_id', versionId)
          .eq('age_group', 'صغار');

      final adultsCount = adultsResponse.length;
      final childrenCount = childrenResponse.length;

      print(
        '📊 Nombre de participants récupéré pour version $versionId: Adultes=$adultsCount, Enfants=$childrenCount',
      );

      return {'adults': adultsCount, 'children': childrenCount};
    } catch (e) {
      print('Erreur lors de la récupération du nombre de participants: $e');
      return {'adults': 0, 'children': 0};
    }
  }
}
