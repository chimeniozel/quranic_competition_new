import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppVersionService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Récupère les informations de version de l'application
  Future<PackageInfo> getCurrentVersion() async {
    return await PackageInfo.fromPlatform();
  }

  /// Vérifie si une mise à jour est requise
  /// Retourne true si l'utilisateur doit mettre à jour, false sinon
  Future<bool> isUpdateRequired() async {
    try {
      final currentVersion = await getCurrentVersion();
      final currentVersionCode = int.parse(currentVersion.buildNumber);

      // Récupérer la version minimale requise depuis Supabase
      final response =
          await _supabase
              .from('app_settings')
              .select('minimum_version_code, force_update_enabled')
              .maybeSingle();

      if (response == null) {
        // Si aucune configuration n'existe, ne pas forcer la mise à jour
        return false;
      }

      final forceUpdateEnabled =
          response['force_update_enabled'] as bool? ?? false;
      if (!forceUpdateEnabled) {
        return false;
      }

      final minimumVersionCode = response['minimum_version_code'] as int?;
      if (minimumVersionCode == null) {
        return false;
      }

      // Si la version actuelle est inférieure à la version minimale requise
      return currentVersionCode < minimumVersionCode;
    } catch (e) {
      print('❌ Erreur lors de la vérification de la version: $e');
      // En cas d'erreur, ne pas bloquer l'utilisateur
      return false;
    }
  }

  /// Récupère le message de mise à jour depuis Supabase
  Future<String> getUpdateMessage() async {
    try {
      final response =
          await _supabase
              .from('app_settings')
              .select('update_message')
              .maybeSingle();

      if (response != null && response['update_message'] != null) {
        return response['update_message'] as String;
      }

      // Message par défaut
      return 'يجب تحديث التطبيق إلى أحدث إصدار للاستمرار في الاستخدام.';
    } catch (e) {
      print('❌ Erreur lors de la récupération du message: $e');
      return 'يجب تحديث التطبيق إلى أحدث إصدار للاستمرار في الاستخدام.';
    }
  }

  /// Récupère l'URL de mise à jour depuis Supabase
  Future<String> getUpdateUrl() async {
    try {
      final response =
          await _supabase
              .from('app_settings')
              .select('update_url_android, update_url_ios')
              .maybeSingle();

      if (response != null) {
        // Détecter la plateforme (Android/iOS)
        final androidUrl = response['update_url_android'] as String?;
        final iosUrl = response['update_url_ios'] as String?;

        // URL par défaut pour Android
        const defaultAndroidUrl =
            'https://play.google.com/store/apps/details?id=com.chemeni.quranic_competition';

        // Retourner l'URL Android si disponible, sinon iOS, sinon défaut
        // TODO: Détecter la plateforme réelle avec Platform.isAndroid / Platform.isIOS
        return androidUrl ?? iosUrl ?? defaultAndroidUrl;
      }

      // URL par défaut pour Google Play
      return 'https://play.google.com/store/apps/details?id=com.chemeni.quranic_competition';
    } catch (e) {
      print('❌ Erreur lors de la récupération de l\'URL: $e');
      return 'https://play.google.com/store/apps/details?id=com.chemeni.quranic_competition';
    }
  }
}
