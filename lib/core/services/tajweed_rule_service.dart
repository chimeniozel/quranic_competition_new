import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:quranic_competition/models/tajweed_rule.dart';

class TajweedRuleService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Créer une nouvelle règle de Tajweed
  Future<TajweedRule> createRule({
    required String title,
    required String content,
    required TajweedType type,
    String? videoUrl,
    String? imageUrl,
    required String authorId,
    required String authorName,
  }) async {
    try {
      final now = DateTime.now();
      final ruleData = {
        'title': title,
        'content': content,
        'type': type.name,
        'video_url': videoUrl,
        'image_url': imageUrl,
        'author_id': authorId,
        'author_name': authorName,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
        'is_active': false, // Les nouvelles règles sont non actives par défaut
      };

      final response =
          await _supabase
              .from('tajweed_rules')
              .insert(ruleData)
              .select()
              .single();

      return TajweedRule.fromMap(response);
    } catch (e) {
      print('Erreur lors de la création de la règle de Tajweed: $e');
      throw Exception('Impossible de créer la règle de Tajweed');
    }
  }

  // Récupérer toutes les règles avec pagination (pour les admins)
  Future<Map<String, dynamic>> getRulesWithPagination({
    String searchQuery = '',
    TajweedType? typeFilter,
    int page = 0,
    int limit = 20,
  }) async {
    try {
      var query = _supabase
          .from('tajweed_rules')
          .select('*')
          .order('created_at', ascending: false);

      final allRules = await query;

      List<TajweedRule> rules =
          allRules.map<TajweedRule>((row) => TajweedRule.fromMap(row)).toList();

      // Appliquer le filtre de type côté client
      if (typeFilter != null) {
        rules = rules.where((rule) => rule.type == typeFilter).toList();
      }

      // Appliquer le filtre de recherche côté client
      if (searchQuery.isNotEmpty) {
        rules =
            rules.where((rule) {
              return rule.title.toLowerCase().contains(
                    searchQuery.toLowerCase(),
                  ) ||
                  rule.content.toLowerCase().contains(
                    searchQuery.toLowerCase(),
                  );
            }).toList();
      }

      final totalCount = rules.length;
      final startIndex = page * limit;
      final endIndex = (startIndex + limit).clamp(0, totalCount);

      final paginatedRules = rules.sublist(startIndex, endIndex);
      final hasMore = endIndex < totalCount;

      return {
        'rules': paginatedRules,
        'totalCount': totalCount,
        'hasMore': hasMore,
        'currentPage': page,
      };
    } catch (e) {
      print('Erreur lors de la récupération des règles de Tajweed: $e');
      throw Exception('Impossible de récupérer les règles de Tajweed');
    }
  }

  // Récupérer toutes les règles actives (pour les participants)
  Future<List<TajweedRule>> getActiveRules() async {
    try {
      final rows = await _supabase
          .from('tajweed_rules')
          .select('*')
          .eq('is_active', true)
          .order('created_at', ascending: false);
      return rows.map<TajweedRule>((row) => TajweedRule.fromMap(row)).toList();
    } catch (e) {
      print('Erreur lors de la récupération des règles actives de Tajweed: $e');
      throw Exception('Impossible de récupérer les règles actives de Tajweed');
    }
  }

  // Récupérer les règles actives avec pagination (pour les participants)
  Future<Map<String, dynamic>> getActiveRulesWithPagination({
    String searchQuery = '',
    TajweedType? typeFilter,
    int page = 0,
    int limit = 20,
  }) async {
    try {
      var query = _supabase
          .from('tajweed_rules')
          .select('*')
          .eq('is_active', true) // Seulement les règles actives
          .order('created_at', ascending: false);

      final allRules = await query;

      List<TajweedRule> rules =
          allRules.map<TajweedRule>((row) => TajweedRule.fromMap(row)).toList();

      // Appliquer le filtre de type côté client
      if (typeFilter != null) {
        rules = rules.where((rule) => rule.type == typeFilter).toList();
      }

      // Appliquer le filtre de recherche côté client
      if (searchQuery.isNotEmpty) {
        rules =
            rules.where((rule) {
              return rule.title.toLowerCase().contains(
                    searchQuery.toLowerCase(),
                  ) ||
                  rule.content.toLowerCase().contains(
                    searchQuery.toLowerCase(),
                  );
            }).toList();
      }

      final totalCount = rules.length;
      final startIndex = page * limit;
      final endIndex = (startIndex + limit).clamp(0, totalCount);

      final paginatedRules = rules.sublist(startIndex, endIndex);
      final hasMore = endIndex < totalCount;

      return {
        'rules': paginatedRules,
        'totalCount': totalCount,
        'hasMore': hasMore,
        'currentPage': page,
      };
    } catch (e) {
      print('Erreur lors de la récupération des règles actives de Tajweed: $e');
      throw Exception('Impossible de récupérer les règles actives de Tajweed');
    }
  }

  // Récupérer une règle par ID
  Future<TajweedRule?> getRuleById(String id) async {
    try {
      final response =
          await _supabase
              .from('tajweed_rules')
              .select('*')
              .eq('id', id)
              .single();

      return TajweedRule.fromMap(response);
    } catch (e) {
      print('Erreur lors de la récupération de la règle: $e');
      return null;
    }
  }

  // Mettre à jour une règle
  Future<TajweedRule> updateRule({
    required String id,
    required String title,
    required String content,
    required TajweedType type,
    String? videoUrl,
    String? imageUrl,
  }) async {
    try {
      final now = DateTime.now();
      final updateData = {
        'title': title,
        'content': content,
        'type': type.name,
        'video_url': videoUrl,
        'image_url': imageUrl,
        'updated_at': now.toIso8601String(),
      };

      final response =
          await _supabase
              .from('tajweed_rules')
              .update(updateData)
              .eq('id', id)
              .select()
              .single();

      return TajweedRule.fromMap(response);
    } catch (e) {
      print('Erreur lors de la mise à jour de la règle: $e');
      throw Exception('Impossible de mettre à jour la règle');
    }
  }

  // Basculer le statut actif/inactif d'une règle
  Future<void> toggleRuleStatus(String id) async {
    try {
      // Récupérer la règle actuelle
      final currentRule = await getRuleById(id);
      if (currentRule == null) {
        throw Exception('Règle non trouvée');
      }

      // Basculer le statut
      await _supabase
          .from('tajweed_rules')
          .update({'is_active': !currentRule.isActive})
          .eq('id', id);
    } catch (e) {
      print('Erreur lors du basculement du statut: $e');
      throw Exception('Impossible de basculer le statut de la règle');
    }
  }

  // Supprimer une règle
  Future<void> deleteRule(String id) async {
    try {
      await _supabase.from('tajweed_rules').delete().eq('id', id);
    } catch (e) {
      print('Erreur lors de la suppression de la règle: $e');
      throw Exception('Impossible de supprimer la règle');
    }
  }

  // Récupérer les statistiques des règles
  Future<Map<String, int>> getRulesStats() async {
    try {
      final allRules = await _supabase
          .from('tajweed_rules')
          .select('is_active, type');

      int totalRules = allRules.length;
      int activeRules =
          allRules.where((rule) => rule['is_active'] == true).length;
      int inactiveRules = totalRules - activeRules;
      int postRules = allRules.where((rule) => rule['type'] == 'post').length;
      int videoRules = allRules.where((rule) => rule['type'] == 'video').length;

      return {
        'total': totalRules,
        'active': activeRules,
        'inactive': inactiveRules,
        'posts': postRules,
        'videos': videoRules,
      };
    } catch (e) {
      print('Erreur lors de la récupération des statistiques: $e');
      return {'total': 0, 'active': 0, 'inactive': 0, 'posts': 0, 'videos': 0};
    }
  }
}
