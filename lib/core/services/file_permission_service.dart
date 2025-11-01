import 'dart:io' show Platform;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class FilePermissionService {
  static final FilePermissionService _instance =
      FilePermissionService._internal();
  factory FilePermissionService() => _instance;
  FilePermissionService._internal();

  /// Détermine quelle permission utiliser selon la plateforme
  /// Sur Android 13+ (API 33+), Permission.photos
  /// Sur Android < 13, Permission.storage
  /// Sur iOS, Permission.photos
  Permission _getPermission() {
    if (Platform.isAndroid) {
      // Sur Android, permission_handler devrait automatiquement
      // utiliser la bonne permission selon la version Android
      // mais on peut essayer photos d'abord
      return Permission.photos;
    } else if (Platform.isIOS) {
      return Permission.photos;
    }
    return Permission.photos;
  }

  /// Méthode alternative pour essayer storage sur Android si photos ne fonctionne pas
  Future<bool> _tryRequestPermission(
    Permission permission,
    BuildContext context,
  ) async {
    try {
      var status = await permission.status;
      print('📱 Tentative avec $permission - Statut: $status');

      if (status.isGranted) {
        return true;
      }

      if (status.isPermanentlyDenied) {
        return false; // Ne pas ouvrir les paramètres ici
      }

      // Essayer de demander la permission
      final result = await permission.request();
      print('📱 Résultat de $permission: $result');

      return result.isGranted;
    } catch (e) {
      print('❌ Erreur avec $permission: $e');
      return false;
    }
  }

  /// Vérifie et demande les permissions nécessaires pour accéder aux fichiers/images
  /// Retourne true si la permission est accordée, false sinon
  /// Demande la permission directement dans l'app sans quitter l'application
  Future<bool> requestStoragePermission(BuildContext context) async {
    try {
      final permission = _getPermission();

      // Vérifier d'abord l'état actuel de la permission
      var status = await permission.status;
      print('📱 Statut initial de la permission ($permission): $status');
      print('📱 Plateforme: ${Platform.isIOS ? "iOS" : Platform.isAndroid ? "Android" : "Autre"}');

      // Si la permission est déjà accordée, retourner true
      if (status.isGranted) {
        print('✅ Permission déjà accordée');
        return true;
      }

      // Si la permission est définitivement refusée, on doit ouvrir les paramètres
      if (status.isPermanentlyDenied) {
        print('⚠️ Permission définitivement refusée, ouverture des paramètres');
        return await _showPermissionDeniedDialog(context, permission);
      }

      // Pour TOUS les autres cas (denied, undetermined, restricted, etc.),
      // TOUJOURS demander la permission directement dans l'app
      // Cela affichera un dialogue système natif dans l'app la première fois
      print('📱 Demande de permission - Statut actuel: $status');
      print('📱 Type de permission utilisé: $permission');

      // Sur iOS, il faut parfois vérifier si la permission peut être demandée
      if (Platform.isIOS) {
        // Sur iOS, Permission.photos peut retourner restricted ou denied
        // On doit toujours essayer de demander
        print('🍎 iOS - Demande de permission photos');
      }

      // Essayer d'abord avec Permission.photos (ou storage selon la plateforme)
      var result = await permission.request();
      print('📱 Résultat de la demande ($permission): $result');
      
      // Vérifier à nouveau le statut après la demande (parfois nécessaire sur iOS)
      var newStatus = await permission.status;
      print('📱 Statut après demande: $newStatus');
      
      // Utiliser le nouveau statut si la demande a changé quelque chose
      if (newStatus.isGranted && !result.isGranted) {
        print('✅ Permission accordée après vérification du statut');
        return true;
      }
      
      // Si sur iOS, vérifier à nouveau le statut car il peut changer après la demande
      if (Platform.isIOS && !result.isGranted) {
        // Sur iOS, le statut peut changer après la demande
        // Attendre un peu et revérifier
        await Future.delayed(const Duration(milliseconds: 300));
        final iosStatus = await permission.status;
        print('🍎 iOS - Statut après attente: $iosStatus');
        if (iosStatus.isGranted) {
          print('✅ Permission accordée sur iOS');
          return true;
        }
      }

      // Si sur Android et que photos ne fonctionne pas (denied mais pas de dialogue),
      // essayer Permission.storage comme fallback
      if (Platform.isAndroid &&
          result.isDenied &&
          !result.isPermanentlyDenied &&
          newStatus.isDenied &&
          status == PermissionStatus.denied) {
        print('📱 Essai avec Permission.storage en fallback');
        final storageResult = await _tryRequestPermission(
          Permission.storage,
          context,
        );
        if (storageResult) {
          print('✅ Permission.storage accordée');
          return true;
        }
      }

      // Utiliser le résultat de la demande
      if (result.isGranted || newStatus.isGranted) {
        print('✅ Permission accordée');
        return true;
      }

      // Si la permission est refusée mais pas définitivement,
      // afficher un dialogue avec option d'ouvrir les paramètres
      // car l'utilisateur doit activer la permission manuellement
      if (result.isDenied) {
        return await _showPermissionDeniedDialog(context, permission);
      }

      // Si la permission est définitivement refusée après la demande,
      // on doit ouvrir les paramètres
      if (result.isPermanentlyDenied) {
        return await _showPermissionDeniedDialog(context, permission);
      }

      return false;
    } catch (e) {
      print('❌ Erreur lors de la demande de permission: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في طلب الإذن: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
      return false;
    }
  }

  /// Affiche un dialogue informant l'utilisateur que la permission est nécessaire
  /// et lui demande s'il veut ouvrir les paramètres pour l'accorder
  Future<bool> _showPermissionDeniedDialog(
    BuildContext context,
    Permission permission,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppTheme.backgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusL),
          ),
          title: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: AppTheme.warningColor,
                size: 28,
              ),
              const SizedBox(width: AppTheme.spacingS),
              Expanded(
                child: Text(
                  'إذن الوصول إلى الملفات',
                  style: AppTheme.headingMedium.copyWith(
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'يحتاج التطبيق إلى إذن الوصول إلى الصور والملفات لتحميل الصور.',
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.textPrimaryColor,
                ),
              ),
              const SizedBox(height: AppTheme.spacingS),
              Text(
                'هل تريد فتح إعدادات التطبيق لمنح هذا الإذن؟',
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.textPrimaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'إلغاء',
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.textSecondaryColor,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                ),
              ),
              child: Text(
                'فتح الإعدادات',
                style: AppTheme.bodyMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );

    // Si l'utilisateur veut ouvrir les paramètres
    if (result == true) {
      final opened = await openAppSettings();
      if (opened) {
        // Attendre un peu pour que l'utilisateur revienne de les paramètres
        await Future.delayed(const Duration(milliseconds: 500));

        // Vérifier à nouveau la permission après le retour des paramètres
        final newStatus = await permission.status;
        if (newStatus.isGranted) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.white),
                    const SizedBox(width: AppTheme.spacingS),
                    Text('تم منح الإذن بنجاح'),
                  ],
                ),
                backgroundColor: AppTheme.successColor,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusS),
                ),
              ),
            );
          }
          return true;
        }
      }
      return false;
    }

    return false;
  }

  /// Vérifie si la permission est déjà accordée (sans demander)
  Future<bool> hasStoragePermission() async {
    try {
      final permission = _getPermission();
      final status = await permission.status;
      return status.isGranted;
    } catch (e) {
      print('❌ Erreur lors de la vérification de la permission: $e');
      return false;
    }
  }
}
