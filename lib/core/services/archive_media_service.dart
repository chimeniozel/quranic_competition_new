import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:quranic_competition/models/archive_media.dart';

class ArchiveMediaService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Récupérer tous les médias d'une version de compétition
  Future<List<ArchiveMedia>> getMediaByVersionId(String versionId) async {
    try {
      final response = await _supabase
          .from('archive_media')
          .select('*')
          .eq('version_id', versionId)
          .order('order');

      if (response == null || response.isEmpty) {
        return [];
      }

      return (response as List)
          .map((json) => ArchiveMedia.fromMap(json))
          .toList();
    } catch (e) {
      print(
        'Erreur lors de la récupération des médias pour version $versionId: $e',
      );
      // Retourner une liste vide au lieu de lever une exception
      return [];
    }
  }

  // Récupérer tous les médias
  Future<List<ArchiveMedia>> getAllMedia() async {
    try {
      // Essayer d'abord avec la nouvelle structure
      final response = await _supabase
          .from('archive_media')
          .select('*')
          .order('order');

      if (response == null || response.isEmpty) {
        return [];
      }

      return (response as List)
          .map((json) => ArchiveMedia.fromMap(json))
          .toList();
    } catch (e) {
      print('Erreur lors de la récupération de tous les médias: $e');
      print(
        'La table archive_media pourrait ne pas être correctement configurée',
      );
      // Retourner une liste vide au lieu de lever une exception
      return [];
    }
  }

  // Méthode alternative pour récupérer les médias avec gestion d'erreur améliorée
  Future<List<ArchiveMedia>> getAllMediaSafe() async {
    try {
      // Vérifier d'abord si la table existe et a les bonnes colonnes
      final response = await _supabase
          .from('archive_media')
          .select(
            'id, version_id, type, url, title, is_active, order, created_at',
          )
          .order('order');

      if (response == null) {
        return [];
      }

      return (response as List)
          .map((json) {
            try {
              return ArchiveMedia.fromMap(json);
            } catch (parseError) {
              print(
                'Erreur de parsing pour le média: $json, erreur: $parseError',
              );
              return null;
            }
          })
          .where((media) => media != null)
          .cast<ArchiveMedia>()
          .toList();
    } catch (e) {
      print('Erreur lors de la récupération sécurisée des médias: $e');
      return [];
    }
  }

  // Créer un nouveau média
  Future<ArchiveMedia> createMedia({
    required String versionId,
    required MediaType type,
    required String url,
    String? thumbnailUrl,
    String? title,
    String? description,
    required int order,
  }) async {
    try {
      final response =
          await _supabase
              .from('archive_media')
              .insert({
                'version_id': versionId, // Utiliser seulement version_id
                'type': type.name,
                'url': url,
                'thumbnail_url': thumbnailUrl,
                'title': title,
                'description': description,
                'order': order,
                'is_active': true,
              })
              .select()
              .single();

      return ArchiveMedia.fromMap(response);
    } catch (e) {
      print('Erreur lors de la création du média: $e');
      print('Type d\'erreur: ${e.runtimeType}');
      throw Exception('Impossible de créer le média: $e');
    }
  }

  // Mettre à jour un média
  Future<ArchiveMedia> updateMedia({
    required String id,
    String? url,
    String? thumbnailUrl,
    String? title,
    String? description,
    int? order,
  }) async {
    try {
      Map<String, dynamic> updateData = {};
      if (url != null) updateData['url'] = url;
      if (thumbnailUrl != null) updateData['thumbnail_url'] = thumbnailUrl;
      if (title != null) updateData['title'] = title;
      if (description != null) updateData['description'] = description;
      if (order != null) updateData['order'] = order;

      final response =
          await _supabase
              .from('archive_media')
              .update(updateData)
              .eq('id', id)
              .select()
              .single();

      return ArchiveMedia.fromMap(response);
    } catch (e) {
      print('Erreur lors de la mise à jour du média: $e');
      throw Exception('Impossible de mettre à jour le média');
    }
  }

  // Supprimer un média
  Future<void> deleteMedia(String id) async {
    try {
      await _supabase.from('archive_media').delete().eq('id', id);
    } catch (e) {
      print('Erreur lors de la suppression du média: $e');
      throw Exception('Impossible de supprimer le média');
    }
  }

  // Supprimer tous les médias d'une version de compétition
  Future<void> deleteAllMediaByVersionId(String versionId) async {
    try {
      await _supabase
          .from('archive_media')
          .delete()
          .eq('version_id', versionId);
    } catch (e) {
      print('Erreur lors de la suppression des médias: $e');
      throw Exception('Impossible de supprimer les médias');
    }
  }

  // Réorganiser l'ordre des médias
  Future<void> reorderMedia(List<ArchiveMedia> media) async {
    try {
      for (int i = 0; i < media.length; i++) {
        await _supabase
            .from('archive_media')
            .update({'order': i + 1})
            .eq('id', media[i].id);
      }
    } catch (e) {
      print('Erreur lors de la réorganisation des médias: $e');
      throw Exception('Impossible de réorganiser les médias');
    }
  }

  // Upload d'image vers Supabase Storage
  Future<String> uploadImageToStorage(File imageFile, String fileName) async {
    try {
      final filePath = 'archive-media/$fileName';

      await _supabase.storage
          .from('images')
          .uploadBinary(
            filePath,
            await imageFile.readAsBytes(),
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: false,
            ),
          );

      return _supabase.storage.from('images').getPublicUrl(filePath);
    } catch (e) {
      print('Erreur lors de l\'upload de l\'image: $e');
      throw Exception('Impossible d\'uploader l\'image');
    }
  }

  // Créer plusieurs médias en une fois
  Future<List<ArchiveMedia>> createMultipleMedia({
    required String versionId,
    required List<Map<String, dynamic>> mediaData,
  }) async {
    try {
      final List<Map<String, dynamic>> insertData =
          mediaData.map((data) {
            return {
              'version_id': versionId,
              'type': data['type'],
              'url': data['url'],
              'thumbnail_url': data['thumbnailUrl'],
              'title': data['title'],
              'description': data['description'],
              'order': data['order'],
              'is_active': true,
            };
          }).toList();

      final response =
          await _supabase.from('archive_media').insert(insertData).select();

      return (response as List)
          .map((json) => ArchiveMedia.fromMap(json))
          .toList();
    } catch (e) {
      print('Erreur lors de la création des médias: $e');
      throw Exception('Impossible de créer les médias');
    }
  }

  // Récupérer les médias par type
  Future<List<ArchiveMedia>> getMediaByType(
    String versionId,
    MediaType type,
  ) async {
    try {
      final response = await _supabase
          .from('archive_media')
          .select('*')
          .eq('version_id', versionId)
          .eq('type', type.name)
          .order('order');

      return (response as List)
          .map((json) => ArchiveMedia.fromMap(json))
          .toList();
    } catch (e) {
      print('Erreur lors de la récupération des médias par type: $e');
      throw Exception('Impossible de récupérer les médias par type');
    }
  }

  // Récupérer tous les médias d'une compétition (version directe)
  Future<List<ArchiveMedia>> getMediaByCompetitionVersion(
    String versionId,
  ) async {
    try {
      final response = await _supabase
          .from('archive_media')
          .select('*')
          .eq('version_id', versionId)
          .order('order');

      return (response as List)
          .map((json) => ArchiveMedia.fromMap(json))
          .toList();
    } catch (e) {
      print('Erreur lors de la récupération des médias par compétition: $e');
      throw Exception('Impossible de récupérer les médias de la compétition');
    }
  }

  // Changer le statut d'un média
  Future<ArchiveMedia> toggleMediaStatus(String id) async {
    try {
      // D'abord, récupérer le média actuel
      final currentMedia =
          await _supabase
              .from('archive_media')
              .select('*')
              .eq('id', id)
              .single();

      final newStatus = !(currentMedia['is_active'] as bool);

      final response =
          await _supabase
              .from('archive_media')
              .update({'is_active': newStatus})
              .eq('id', id)
              .select()
              .single();

      return ArchiveMedia.fromMap(response);
    } catch (e) {
      print('Erreur lors du changement de statut du média: $e');
      throw Exception('Impossible de changer le statut du média');
    }
  }

  // Récupérer les médias avec filtres (actif/inactif, type)
  Future<List<ArchiveMedia>> getMediaWithFilters({
    required String versionId,
    MediaType? type,
    bool? isActive,
  }) async {
    try {
      var query = _supabase
          .from('archive_media')
          .select('*')
          .eq('version_id', versionId);

      if (type != null) {
        query = query.eq('type', type.name);
      }

      if (isActive != null) {
        query = query.eq('is_active', isActive);
      }

      final response = await query.order('order');

      return (response as List)
          .map((json) => ArchiveMedia.fromMap(json))
          .toList();
    } catch (e) {
      print('Erreur lors de la récupération des médias filtrés: $e');
      throw Exception('Impossible de récupérer les médias filtrés');
    }
  }
}
