// lib/core/services/auth_service.dart

import 'package:flutter/rendering.dart';
import 'package:quranic_competition/models/app_user.dart';
import 'package:quranic_competition/models/user_role.dart';
import 'package:quranic_competition/core/services/permission_service.dart';
import 'package:quranic_competition/core/services/error_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final ErrorService _errorService = ErrorService();

  /// Inscription d'un nouvel utilisateur avec téléphone, mot de passe, nom complet et rôle.
  Future<String?> signUp({
    required String phone,
    required String email,
    required String password,
    required String fullName,
    required String role, // ex: jury, admin
  }) async {
    try {
      // Validation préliminaire
      final validationError = _validateSignUpData(
        email,
        password,
        phone,
        fullName,
      );
      if (validationError != null) return validationError;

      final res = await _supabase.auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: 'com.example.quranic_competition://login-callback',
        data: {'full_name': fullName, 'role': role, 'is_verified': false},
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
              'phone': phone,
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

      return null; // Succès
    } catch (e) {
      debugPrint('Erreur signIn: $e');
      return _errorService.analyzeException(e);
    }
  }

  /// Déconnexion de l'utilisateur.
  Future<void> signOut() async {
    // Nettoyer les permissions avant la déconnexion
    PermissionService().clearPermissions();
    await Supabase.instance.client.auth.signOut();
  }

  /// Initialiser les permissions de l'utilisateur après la connexion
  Future<void> _initializeUserPermissions(String userId) async {
    try {
      // Récupérer le rôle de l'utilisateur depuis la table profiles
      final response =
          await _supabase
              .from('profiles')
              .select('role')
              .eq('id', userId)
              .single();

      if (response['role'] != null) {
        final userRole = UserRole.fromString(response['role']);
        PermissionService().setUserRole(userRole);

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
    return RegExp(r'^\+?[\d\s\-\(\)]{8,15}$').hasMatch(phone);
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
