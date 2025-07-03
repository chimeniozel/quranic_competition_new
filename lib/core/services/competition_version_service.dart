import 'package:flutter/material.dart';
import 'package:quranic_competition/models/round.dart';
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

  Future<List<CompetitionVersion>> fetchMyVersions() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      throw Exception("Utilisateur non connecté");
    }

    final userId = user.id;

    final response = await _supabase
        .from('jury_assignments')
        .select('version:competition_versions(*)') // alias version
        .eq('user_id', userId);

    return (response as List)
        .map((row) => CompetitionVersion.fromMap(row['version']))
        .toList();
  }

Future<void> createVersion({
    required String name,
    required int year,
    required int maxAdults,
    required int maxChildren,
    required bool isRegistrationOpen,
  }) async {
    final response = await _supabase.from('competition_versions').insert({
      'name': name,
      'year': year,
      'max_adults': maxAdults,
      'max_children': maxChildren,
      'is_registration_open': isRegistrationOpen,
      'is_active': true,
    }).select().single();

    final versionId = response['id'] as String;

    // Créer automatiquement 2 tours
    await _supabase.from('rounds').insert([
      {
        'version_id': versionId,
        'number': 1,
        'name': 'الجولة الأولى',
        'is_active': true,
      },
      {
        'version_id': versionId,
        'number': 2,
        'name': 'الجولة الثانية',
        'is_active': false,
      }
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

  Future<void> deleteVersion(String versionId) async {
    final response =
        await _supabase
            .from('competition_versions')
            .delete()
            .eq('id', versionId)
            .select(); // récupérer les données supprimées

    print('Delete response: $response');

    if ((response.isEmpty)) {
      throw Exception('Erreur lors de la suppression : version introuvable');
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

  

}

/// Exemple d'utilisation dans un Widget ou Controller (ne mets pas cette fonction dans le service !)
Future<void> onRegister(BuildContext context) async {
  final service = CompetitionVersionService();

  try {
    final canAdd = await service.tryAddParticipant(
      versionId: 'uuid-de-la-version',
      ageGroup: 'كبار', // ou 'صغار'
      fullName: 'Ahmed Mohamed',
      phone: '+22212345678',
      password: 'secret123',
    );

    if (!canAdd) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'La limite maximale de participants pour ce groupe est atteinte.',
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Inscription réussie !')));
    }
  } catch (e) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Erreur : $e')));
  }

  
}
