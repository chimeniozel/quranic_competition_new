import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:quranic_competition/models/quranic_benefit.dart';

class QuranicBenefitService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Récupère tous les bénéfices coraniques avec pagination
  Future<Map<String, dynamic>> getBenefitsWithPagination({
    String searchQuery = '',
    int page = 0,
    int limit = 20,
  }) async {
    try {
      // Récupérer tous les bénéfices d'abord
      var query = _supabase
          .from('quranic_benefits')
          .select('*')
          .order('created_at', ascending: false);

      final allBenefits = await query;

      List<QuranicBenefit> benefits =
          allBenefits
              .map<QuranicBenefit>((row) => QuranicBenefit.fromMap(row))
              .toList();

      // Appliquer le filtre de recherche côté client
      if (searchQuery.isNotEmpty) {
        benefits =
            benefits.where((benefit) {
              return benefit.title.toLowerCase().contains(
                    searchQuery.toLowerCase(),
                  ) ||
                  benefit.content.toLowerCase().contains(
                    searchQuery.toLowerCase(),
                  );
            }).toList();
      }

      final totalCount = benefits.length;
      final startIndex = page * limit;
      final endIndex = (startIndex + limit).clamp(0, totalCount);

      // Pagination côté client
      final paginatedBenefits = benefits.sublist(startIndex, endIndex);
      final hasMore = endIndex < totalCount;

      return {
        'benefits': paginatedBenefits,
        'totalCount': totalCount,
        'hasMore': hasMore,
        'currentPage': page,
      };
    } catch (e) {
      print('Erreur lors de la récupération des bénéfices coraniques: $e');
      throw Exception('Impossible de récupérer les bénéfices coraniques');
    }
  }

  /// Récupère un bénéfice coranique par son ID
  Future<QuranicBenefit?> getBenefitById(String id) async {
    try {
      final data =
          await _supabase
              .from('quranic_benefits')
              .select()
              .eq('id', id)
              .single();

      return QuranicBenefit.fromMap(data);
    } catch (e) {
      print('Erreur lors de la récupération du bénéfice coranique: $e');
      return null;
    }
  }

  /// Crée un nouveau bénéfice coranique
  Future<QuranicBenefit> createBenefit({
    required String title,
    required String content,
    String? imageUrl,
    required String authorId,
    required String authorName,
  }) async {
    try {
      final now = DateTime.now();
      final benefitData = {
        'title': title,
        'content': content,
        'image_url': imageUrl,
        'author_id': authorId,
        'author_name': authorName,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
        'is_active':
            false, // Les nouvelles bénéfices sont non actives par défaut
      };

      final data =
          await _supabase
              .from('quranic_benefits')
              .insert(benefitData)
              .select()
              .single();

      return QuranicBenefit.fromMap(data);
    } catch (e) {
      print('Erreur lors de la création du bénéfice coranique: $e');
      throw Exception('Impossible de créer le bénéfice coranique');
    }
  }

  /// Met à jour un bénéfice coranique existant
  Future<QuranicBenefit> updateBenefit({
    required String id,
    required String title,
    required String content,
    String? imageUrl,
  }) async {
    try {
      final updateData = {
        'title': title,
        'content': content,
        'image_url': imageUrl,
        'updated_at': DateTime.now().toIso8601String(),
      };

      final data =
          await _supabase
              .from('quranic_benefits')
              .update(updateData)
              .eq('id', id)
              .select()
              .single();

      return QuranicBenefit.fromMap(data);
    } catch (e) {
      print('Erreur lors de la mise à jour du bénéfice coranique: $e');
      throw Exception('Impossible de mettre à jour le bénéfice coranique');
    }
  }

  /// Supprime un bénéfice coranique (soft delete)
  Future<bool> deleteBenefit(String id) async {
    try {
      await _supabase
          .from('quranic_benefits')
          .update({
            'is_active': false,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', id);

      return true;
    } catch (e) {
      print('Erreur lors de la suppression du bénéfice coranique: $e');
      return false;
    }
  }

  /// Supprime définitivement un bénéfice coranique
  Future<bool> permanentDeleteBenefit(String id) async {
    try {
      await _supabase.from('quranic_benefits').delete().eq('id', id);

      return true;
    } catch (e) {
      print(
        'Erreur lors de la suppression définitive du bénéfice coranique: $e',
      );
      return false;
    }
  }

  /// Active/Désactive un bénéfice coranique
  Future<bool> toggleBenefitStatus(String id, bool isActive) async {
    try {
      await _supabase
          .from('quranic_benefits')
          .update({
            'is_active': isActive,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', id);

      return true;
    } catch (e) {
      print('Erreur lors du changement de statut du bénéfice coranique: $e');
      return false;
    }
  }

  /// Récupère les bénéfices coraniques actifs pour l'affichage public
  Future<List<QuranicBenefit>> getActiveBenefits({int limit = 10}) async {
    try {
      final data = await _supabase
          .from('quranic_benefits')
          .select()
          .eq('is_active', true)
          .order('created_at', ascending: false)
          .limit(limit);

      return data
          .map<QuranicBenefit>((row) => QuranicBenefit.fromMap(row))
          .toList();
    } catch (e) {
      print('Erreur lors de la récupération des bénéfices actifs: $e');
      return [];
    }
  }

  /// Récupère les bénéfices coraniques actifs avec pagination pour les participants
  Future<Map<String, dynamic>> getActiveBenefitsWithPagination({
    String searchQuery = '',
    int page = 0,
    int limit = 20,
  }) async {
    try {
      // Récupérer seulement les bénéfices actifs
      var query = _supabase
          .from('quranic_benefits')
          .select('*')
          .eq('is_active', true) // Seulement les bénéfices actives
          .order('created_at', ascending: false);

      final allBenefits = await query;

      List<QuranicBenefit> benefits =
          allBenefits
              .map<QuranicBenefit>((row) => QuranicBenefit.fromMap(row))
              .toList();

      // Appliquer le filtre de recherche côté client
      if (searchQuery.isNotEmpty) {
        benefits =
            benefits.where((benefit) {
              return benefit.title.toLowerCase().contains(
                    searchQuery.toLowerCase(),
                  ) ||
                  benefit.content.toLowerCase().contains(
                    searchQuery.toLowerCase(),
                  );
            }).toList();
      }

      final totalCount = benefits.length;
      final startIndex = page * limit;
      final endIndex = (startIndex + limit).clamp(0, totalCount);

      // Pagination côté client
      final paginatedBenefits = benefits.sublist(startIndex, endIndex);
      final hasMore = endIndex < totalCount;

      return {
        'benefits': paginatedBenefits,
        'totalCount': totalCount,
        'hasMore': hasMore,
        'currentPage': page,
      };
    } catch (e) {
      print(
        'Erreur lors de la récupération des bénéfices actifs avec pagination: $e',
      );
      throw Exception('Impossible de récupérer les bénéfices actifs');
    }
  }
}
