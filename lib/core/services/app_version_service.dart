import 'dart:io' show Platform;

import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/app_settings.dart';
import 'store_version_service.dart';

class AppVersionService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Récupère les informations de version de l'application
  Future<PackageInfo> getCurrentVersion() async {
    return await PackageInfo.fromPlatform();
  }

  /// Nom de version de l'application en cours d'exécution (« 8.3.0 »).
  Future<String> getCurrentVersionName() async {
    final info = await getCurrentVersion();
    return info.version;
  }

  /// Build number de l'application en cours d'exécution.
  Future<int> getCurrentBuildNumber() async {
    final info = await getCurrentVersion();
    return int.tryParse(info.buildNumber) ?? 0;
  }

  /// Paramètres de mise à jour forcée (ligne unique de `app_settings`).
  ///
  /// Retourne null si la table est vide ou inaccessible : l'appelant décide
  /// alors quoi faire (ne jamais bloquer l'utilisateur, côté application).
  Future<AppSettings?> getSettings() async {
    try {
      final response =
          await _supabase.from('app_settings').select().maybeSingle();

      if (response == null) return null;
      return AppSettings.fromMap(response);
    } catch (e) {
      print('❌ Erreur lors de la récupération des paramètres: $e');
      return null;
    }
  }

  /// Enregistre les paramètres (écran d'administration).
  ///
  /// Met à jour la ligne existante, ou la crée si la table est vide.
  Future<void> saveSettings(AppSettings settings) async {
    final data = settings.toMap();

    if (settings.id != null) {
      await _supabase.from('app_settings').update(data).eq('id', settings.id!);
      return;
    }

    // Aucune ligne encore : on regarde s'il en existe une avant d'insérer,
    // la table ne devant contenir qu'un seul enregistrement.
    final existing =
        await _supabase.from('app_settings').select('id').maybeSingle();

    if (existing != null) {
      await _supabase
          .from('app_settings')
          .update(data)
          .eq('id', existing['id'] as String);
      return;
    }

    await _supabase.from('app_settings').insert(data);
  }

  /// Build number minimal exigé sur la plateforme courante.
  int _minimumBuildFor(AppSettings settings) {
    if (Platform.isIOS) return settings.minimumBuildIos;
    return settings.minimumBuildAndroid;
  }

  /// Version minimale exigée sur la plateforme courante (vide si non définie).
  String _minimumVersionFor(AppSettings settings) {
    if (Platform.isIOS) return settings.minimumVersionIos;
    return settings.minimumVersionAndroid;
  }

  /// Vérifie si une mise à jour est requise
  /// Retourne true si l'utilisateur doit mettre à jour, false sinon
  Future<bool> isUpdateRequired() async {
    try {
      final settings = await getSettings();
      if (settings == null || !settings.forceUpdateEnabled) return false;

      // Réglage principal : comparaison par numéro de version, celui que
      // publient les stores et que l'administrateur voit.
      final minimumVersion = _minimumVersionFor(settings);
      if (minimumVersion.isNotEmpty) {
        final currentVersion = await getCurrentVersionName();
        return StoreVersionService.compareVersions(
              currentVersion,
              minimumVersion,
            ) <
            0;
      }

      // Repli : comparaison par build number. Chaque plateforme a le sien,
      // les comparer entre elles n'aurait aucun sens.
      final currentBuild = await getCurrentBuildNumber();
      return currentBuild < _minimumBuildFor(settings);
    } catch (e) {
      print('❌ Erreur lors de la vérification de la version: $e');
      // En cas d'erreur, ne pas bloquer l'utilisateur
      return false;
    }
  }

  /// Récupère le message de mise à jour depuis Supabase
  Future<String> getUpdateMessage() async {
    final settings = await getSettings();
    return settings?.updateMessage ?? AppSettings.defaultMessage;
  }

  /// Lien de téléchargement correspondant à la plateforme courante.
  Future<String> getUpdateUrl() async {
    final settings = await getSettings() ?? AppSettings.defaults();

    return Platform.isIOS ? settings.updateUrlIos : settings.updateUrlAndroid;
  }
}
