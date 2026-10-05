// lib/core/services/auth_service.dart

import 'package:flutter/rendering.dart';
import 'package:quranic_competition/models/app_user.dart';
import 'package:quranic_competition/models/user_role.dart';
import 'package:quranic_competition/core/services/permission_service.dart';
import 'package:quranic_competition/core/services/error_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Dernier email utilisé, gardé sur l'appareil pour pré-remplir la connexion
  static const _lastEmailKey = 'last_login_email';

  /// Email du dernier compte connecté sur cet appareil (null si aucun).
  static Future<String?> getLastEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString(_lastEmailKey);
      return (email == null || email.isEmpty) ? null : email;
    } catch (e) {
      debugPrint('Erreur lecture du dernier email: $e');
      return null;
    }
  }

  static Future<void> _saveLastEmail(String? email) async {
    if (email == null || email.trim().isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastEmailKey, email.trim());
    } catch (e) {
      debugPrint('Erreur sauvegarde du dernier email: $e');
    }
  }

  static Future<void> _clearLastEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_lastEmailKey);
    } catch (e) {
      debugPrint('Erreur suppression du dernier email: $e');
    }
  }

  final ErrorService _errorService = ErrorService();

  /// Inscription d'un nouvel utilisateur avec téléphone, mot de passe, nom complet et rôle.
  Future<String?> signUp({
    required String countryCode,
    required String phone,
    required String email,
    required String password,
    required String fullName,
    required String role, // ex: jury, admin
  }) async {
    try {
      final normalizedCountryCode = countryCode.trim();
      final countryDigits = normalizedCountryCode.replaceAll(
        RegExp(r'[^\d]'),
        '',
      );
      if (countryDigits.isEmpty) {
        return 'رمز الدولة غير صالح';
      }

      final cleanedPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
      if (cleanedPhone.isEmpty) {
        return 'رقم الهاتف غير صالح';
      }

      final fullPhone = '+$countryDigits$cleanedPhone';

      // Validation préliminaire
      final validationError = _validateSignUpData(
        email,
        password,
        fullPhone,
        fullName,
      );
      if (validationError != null) return validationError;

      final existingPhone =
          await _supabase
              .from('profiles')
              .select('id')
              .eq('phone', fullPhone)
              .maybeSingle();

      if (existingPhone != null) {
        return 'رقم الهاتف مستخدم مسبقاً';
      }

      final res = await _supabase.auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: 'com.chemeni.quranic-competitions://login-callback',
        data: {'full_name': fullName, 'role': role, 'is_validated': false},
      );

      final user = res.user;
      if (user == null) {
        return _errorService.getErrorMessage('USER_CREATION_FAILED');
      }

      // Le trigger handle_new_user() va automatiquement créer le profil
      // Mais nous pouvons mettre à jour le profil avec les informations supplémentaires
      try {
        await _supabase
            .from('profiles')
            .update({
              'full_name': fullName,
              'phone': fullPhone,
              'role': role,
              'is_validated': false,
            })
            .eq('id', user.id);
      } catch (e) {
        debugPrint('Erreur lors de la mise à jour du profil: $e');
        // Ce n'est pas critique, le profil existe déjà grâce au trigger
      }

      return null; // Succès
    } catch (e) {
      debugPrint('Erreur signUp: $e');
      return _errorService.analyzeException(e);
    }
  }

  /// Connexion avec email et mot de passe.
  Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      // Validation préliminaire
      if (email.isEmpty || password.isEmpty) {
        return _errorService.getErrorMessage('VALIDATION_REQUIRED');
      }

      if (!_isValidEmail(email)) {
        return _errorService.getErrorMessage('AUTH_INVALID_EMAIL');
      }

      final res = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (res.user == null) {
        return _errorService.getErrorMessage('AUTH_INVALID_CREDENTIALS');
      }

      // Initialiser les permissions après la connexion
      await _initializeUserPermissions(res.user!.id);
      await _saveLastEmail(res.user!.email ?? email);

      return null; // Succès
    } catch (e) {
      debugPrint('Erreur signIn: $e');
      return _errorService.analyzeException(e);
    }
  }

  /// Déconnexion de l'utilisateur.
  Future<void> signOut() async {
    // Garder l'email pour pré-remplir la prochaine connexion
    await _saveLastEmail(_supabase.auth.currentUser?.email);
    // Nettoyer les permissions avant la déconnexion
    PermissionService().clearPermissions();
    await Supabase.instance.client.auth.signOut();
  }

  /// Suppression définitive du compte de l'utilisateur connecté.
  /// Retourne null en cas de succès, sinon un message d'erreur.
  Future<String?> deleteAccount() async {
    try {
      await _supabase.rpc('delete_own_account');
    } on PostgrestException catch (e) {
      debugPrint('Erreur deleteAccount: $e');
      if (e.message.contains('LAST_SUPER_ADMIN')) {
        return 'لا يمكن حذف حساب المدير العام الوحيد. قم بتعيين مدير عام آخر أولاً.';
      }
      return _errorService.analyzeException(e);
    } catch (e) {
      debugPrint('Erreur deleteAccount: $e');
      return _errorService.analyzeException(e);
    }

    // Le compte n'existe plus : la session locale doit être fermée
    try {
      await signOut();
    } catch (e) {
      debugPrint('Erreur signOut après suppression du compte: $e');
    }
    // Compte supprimé : on ne garde pas son email sur l'appareil
    await _clearLastEmail();
    return null;
  }

  /// Initialiser les permissions de l'utilisateur après la connexion
  Future<void> _initializeUserPermissions(String userId) async {
    try {
      // Récupérer le rôle et les permissions en une seule requête
      final response =
          await _supabase
              .from('profiles')
              .select(
                'role, can_create_versions, can_publish_content, '
                'can_validate_accounts, can_delete, can_modify, '
                'can_modify_versions, can_assign_roles, can_view_content',
              )
              .eq('id', userId)
              .maybeSingle();

      final roleCode = response?['role'] as String?;
      if (roleCode != null) {
        final userRole = UserRole.fromString(roleCode);
        final basePermissions = UserPermissions.forRole(userRole);

        // Utiliser les permissions de la DB si disponibles, sinon utiliser les permissions par défaut
        UserPermissions permissions = basePermissions;

        // Vérifier si les colonnes de permissions existent (non null)
        final hasCustomPermissions =
            response?['can_create_versions'] != null ||
            response?['can_publish_content'] != null ||
            response?['can_validate_accounts'] != null;

        if (hasCustomPermissions && response != null) {
          permissions = UserPermissions.withOverrides(
            basePermissions,
            response,
          );
        }

        PermissionService().setUserRole(
          userRole,
          customPermissions: permissions,
        );

        // Mettre à jour les métadonnées Supabase pour conserver le rôle côté client
        final currentUser = _supabase.auth.currentUser;
        if (currentUser != null) {
          final currentMetaRole = currentUser.userMetadata?['role'];
          if (currentMetaRole != userRole.code) {
            try {
              await _supabase.auth.updateUser(
                UserAttributes(data: {'role': userRole.code}),
              );
            } catch (e) {
              debugPrint('⚠️ Impossible de mettre à jour les métadonnées: $e');
            }
          }
        }

        debugPrint('🔐 Permissions initialisées pour ${userRole.displayName}');
      } else {
        // Rôle par défaut si non trouvé
        PermissionService().setUserRole(UserRole.member);
        debugPrint('🔐 Rôle par défaut assigné: Membre ordinaire');
      }
    } catch (e) {
      debugPrint('❌ Erreur lors de l\'initialisation des permissions: $e');
      // Rôle par défaut en cas d'erreur
      PermissionService().setUserRole(UserRole.member);
    }
  }

  /// Initialiser les permissions pour l'utilisateur actuel (à appeler au démarrage de l'app)
  Future<void> initializeCurrentUserPermissions() async {
    final user = _supabase.auth.currentUser;
    if (user != null) {
      await _initializeUserPermissions(user.id);
    }
  }

  /// Récupérer le profil utilisateur actuel depuis la table profiles.
  Future<AppUser?> getUserProfile() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    final response =
        await _supabase
            .from('profiles')
            .select()
            .eq('id', user.id)
            .maybeSingle();

    if (response == null) {
      print('Profil utilisateur non trouvé');
      return null;
    }

    return AppUser.fromMap(response);
  }

  /// Validation des données d'inscription
  String? _validateSignUpData(
    String email,
    String password,
    String phone,
    String fullName,
  ) {
    // Validation du nom complet
    if (fullName.trim().isEmpty) {
      return _errorService.getErrorMessage('VALIDATION_REQUIRED');
    }
    if (fullName.length < 2) {
      return _errorService.getErrorMessage('VALIDATION_TOO_SHORT');
    }

    // Validation de l'email
    if (email.trim().isEmpty) {
      return _errorService.getErrorMessage('VALIDATION_REQUIRED');
    }
    if (!_isValidEmail(email)) {
      return _errorService.getErrorMessage('AUTH_INVALID_EMAIL');
    }

    // Validation du téléphone
    if (phone.trim().isEmpty) {
      return _errorService.getErrorMessage('VALIDATION_REQUIRED');
    }
    if (!_isValidPhone(phone)) {
      return _errorService.getErrorMessage('AUTH_INVALID_PHONE');
    }

    // Validation du mot de passe
    if (password.isEmpty) {
      return _errorService.getErrorMessage('VALIDATION_REQUIRED');
    }
    if (!_isValidPassword(password)) {
      return _errorService.getErrorMessage('AUTH_WEAK_PASSWORD');
    }

    return null; // Pas d'erreur
  }

  /// Valide un email
  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  /// Valide un numéro de téléphone
  bool _isValidPhone(String phone) {
    final normalized = phone.trim();
    if (!normalized.startsWith('+')) {
      return false;
    }

    final digits = normalized.substring(1);
    if (digits.isEmpty || digits.length < 7 || digits.length > 15) {
      return false;
    }

    if (!RegExp(r'^\d+$').hasMatch(digits)) {
      return false;
    }

    return true;
  }

  /// Valide un mot de passe
  bool _isValidPassword(String password) {
    // Au moins 8 caractères, une majuscule, une minuscule, un chiffre
    if (password.length < 8) return false;
    if (!password.contains(RegExp(r'[A-Z]'))) return false;
    if (!password.contains(RegExp(r'[a-z]'))) return false;
    if (!password.contains(RegExp(r'[0-9]'))) return false;
    return true;
  }
}
