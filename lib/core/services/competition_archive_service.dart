import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:quranic_competition/models/competition_archive.dart';
import 'package:quranic_competition/models/competition_version.dart';

class CompetitionArchiveService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Récupérer toutes les archives avec pagination
  Future<List<CompetitionArchive>> getArchivesWithPagination({
    int page = 0,
    int limit = 20,
    String? searchQuery,
  }) async {
    try {
      var query = _supabase
          .from('competition_archives')
          .select('*')
          .order('event_date', ascending: false)
          .range(page * limit, (page + 1) * limit - 1);

      final response = await query;
      List<CompetitionArchive> archives =
          (response as List)
              .map((json) => CompetitionArchive.fromMap(json))
              .toList();

      // Filtrer par recherche si nécessaire
      if (searchQuery != null && searchQuery.isNotEmpty) {
        archives =
            archives.where((archive) {
              return archive.title.toLowerCase().contains(
                    searchQuery.toLowerCase(),
                  ) ||
                  archive.description.toLowerCase().contains(
                    searchQuery.toLowerCase(),
                  ) ||
                  archive.versionName.toLowerCase().contains(
                    searchQuery.toLowerCase(),
                  );
            }).toList();
      }

      return archives;
    } catch (e) {
      print('Erreur lors de la récupération des archives: $e');
      throw Exception('Impossible de récupérer les archives');
    }
  }

  // Récupérer les archives actives pour les participants
  Future<List<CompetitionArchive>> getActiveArchivesWithPagination({
    int page = 0,
    int limit = 20,
    String? searchQuery,
  }) async {
    try {
      var query = _supabase
          .from('competition_archives')
          .select('*')
          .eq('is_active', true)
          .order('event_date', ascending: false)
          .range(page * limit, (page + 1) * limit - 1);

      final response = await query;
      List<CompetitionArchive> archives =
          (response as List)
              .map((json) => CompetitionArchive.fromMap(json))
              .toList();

      // Filtrer par recherche si nécessaire
      if (searchQuery != null && searchQuery.isNotEmpty) {
        archives =
            archives.where((archive) {
              return archive.title.toLowerCase().contains(
                    searchQuery.toLowerCase(),
                  ) ||
                  archive.description.toLowerCase().contains(
                    searchQuery.toLowerCase(),
                  ) ||
                  archive.versionName.toLowerCase().contains(
                    searchQuery.toLowerCase(),
                  );
            }).toList();
      }

      return archives;
    } catch (e) {
      print('Erreur lors de la récupération des archives actives: $e');
      throw Exception('Impossible de récupérer les archives actives');
    }
  }

  // Récupérer toutes les versions de compétition pour le formulaire
  Future<List<CompetitionVersion>> getCompetitionVersions() async {
    try {
      final response = await _supabase
          .from('competition_versions')
          .select('*')
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => CompetitionVersion.fromMap(json))
          .toList();
    } catch (e) {
      print('Erreur lors de la récupération des versions: $e');
      throw Exception('Impossible de récupérer les versions de compétition');
    }
  }

  // Créer une nouvelle archive
  Future<CompetitionArchive> createArchive({
    required String versionId,
    required String title,
    required String description,
    String? videoUrl,
    String? imageUrl,
    String? thumbnailUrl,
    required DateTime eventDate,
  }) async {
    try {
      // Récupérer le nom de la version
      final versionResponse =
          await _supabase
              .from('competition_versions')
              .select('name')
              .eq('id', versionId)
              .single();

      final versionName = versionResponse['name'] as String;

      final response =
          await _supabase
              .from('competition_archives')
              .insert({
                'version_id': versionId,
                'version_name': versionName,
                'title': title,
                'description': description,
                'video_url': videoUrl,
                'image_url': imageUrl,
                'thumbnail_url': thumbnailUrl,
                'event_date': eventDate.toIso8601String(),
                'is_active': false, // Par défaut non actif
              })
              .select()
              .single();

      return CompetitionArchive.fromMap(response);
    } catch (e) {
      print('Erreur lors de la création de l\'archive: $e');
      throw Exception('Impossible de créer l\'archive');
    }
  }

  // Mettre à jour une archive
  Future<CompetitionArchive> updateArchive({
    required String id,
    String? versionId,
    String? title,
    String? description,
    String? videoUrl,
    String? imageUrl,
    String? thumbnailUrl,
    DateTime? eventDate,
    bool? isActive,
  }) async {
    try {
      Map<String, dynamic> updateData = {};

      if (versionId != null) {
        // Récupérer le nom de la version si elle change
        final versionResponse =
            await _supabase
                .from('competition_versions')
                .select('name')
                .eq('id', versionId)
                .single();
        updateData['version_id'] = versionId;
        updateData['version_name'] = versionResponse['name'] as String;
      }

      if (title != null) updateData['title'] = title;
      if (description != null) updateData['description'] = description;
      if (videoUrl != null) updateData['video_url'] = videoUrl;
      if (imageUrl != null) updateData['image_url'] = imageUrl;
      if (thumbnailUrl != null) updateData['thumbnail_url'] = thumbnailUrl;
      if (eventDate != null)
        updateData['event_date'] = eventDate.toIso8601String();
      if (isActive != null) updateData['is_active'] = isActive;

      final response =
          await _supabase
              .from('competition_archives')
              .update(updateData)
              .eq('id', id)
              .select()
              .single();

      return CompetitionArchive.fromMap(response);
    } catch (e) {
      print('Erreur lors de la mise à jour de l\'archive: $e');
      throw Exception('Impossible de mettre à jour l\'archive');
    }
  }

  // Supprimer une archive
  Future<void> deleteArchive(String id) async {
    try {
      await _supabase.from('competition_archives').delete().eq('id', id);
    } catch (e) {
      print('Erreur lors de la suppression de l\'archive: $e');
      throw Exception('Impossible de supprimer l\'archive');
    }
  }

  // Basculer le statut actif/inactif
  Future<CompetitionArchive> toggleArchiveStatus(String id) async {
    try {
      // Récupérer l'archive actuelle
      final currentResponse =
          await _supabase
              .from('competition_archives')
              .select('is_active')
              .eq('id', id)
              .single();

      final currentStatus = currentResponse['is_active'] as bool;
      final newStatus = !currentStatus;

      // Mettre à jour le statut
      final response =
          await _supabase
              .from('competition_archives')
              .update({'is_active': newStatus})
              .eq('id', id)
              .select()
              .single();

      return CompetitionArchive.fromMap(response);
    } catch (e) {
      print('Erreur lors du changement de statut: $e');
      throw Exception('Impossible de changer le statut de l\'archive');
    }
  }

  // Récupérer une archive par ID
  Future<CompetitionArchive> getArchiveById(String id) async {
    try {
      final response =
          await _supabase
              .from('competition_archives')
              .select('*')
              .eq('id', id)
              .single();

      return CompetitionArchive.fromMap(response);
    } catch (e) {
      print('Erreur lors de la récupération de l\'archive: $e');
      throw Exception('Impossible de récupérer l\'archive');
    }
  }

  // Upload d'image vers Supabase Storage
  Future<String> uploadImageToStorage(File imageFile, String fileName) async {
    try {
      final filePath = 'competition-archives/$fileName';

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
}
