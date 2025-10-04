import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:quranic_competition/models/archive_media.dart';

class ArchiveMediaService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Récupérer tous les médias d'une archive
  Future<List<ArchiveMedia>> getMediaByArchiveId(String archiveId) async {
    try {
      final response = await _supabase
          .from('archive_media')
          .select('*')
          .eq('archive_id', archiveId)
          .order('order');

      return (response as List)
          .map((json) => ArchiveMedia.fromMap(json))
          .toList();
    } catch (e) {
      print('Erreur lors de la récupération des médias: $e');
      throw Exception('Impossible de récupérer les médias');
    }
  }

  // Créer un nouveau média
  Future<ArchiveMedia> createMedia({
    required String archiveId,
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
                'archive_id': archiveId,
                'type': type.name,
                'url': url,
                'thumbnail_url': thumbnailUrl,
                'title': title,
                'description': description,
                'order': order,
              })
              .select()
              .single();

      return ArchiveMedia.fromMap(response);
    } catch (e) {
      print('Erreur lors de la création du média: $e');
      throw Exception('Impossible de créer le média');
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

  // Supprimer tous les médias d'une archive
  Future<void> deleteAllMediaByArchiveId(String archiveId) async {
    try {
      await _supabase
          .from('archive_media')
          .delete()
          .eq('archive_id', archiveId);
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
    required String archiveId,
    required List<Map<String, dynamic>> mediaData,
  }) async {
    try {
      final List<Map<String, dynamic>> insertData =
          mediaData.map((data) {
            return {
              'archive_id': archiveId,
              'type': data['type'],
              'url': data['url'],
              'thumbnail_url': data['thumbnailUrl'],
              'title': data['title'],
              'description': data['description'],
              'order': data['order'],
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
    String archiveId,
    MediaType type,
  ) async {
    try {
      final response = await _supabase
          .from('archive_media')
          .select('*')
          .eq('archive_id', archiveId)
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
}
