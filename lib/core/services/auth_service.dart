// lib/core/services/auth_service.dart

import 'package:flutter/rendering.dart';
import 'package:quranic_competition/models/app_user.dart';
import 'package:quranic_competition/models/user_role.dart';
import 'package:quranic_competition/core/services/permission_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Inscription d'un nouvel utilisateur avec téléphone, mot de passe, nom complet et rôle.
  Future<String?> signUp({
    required String phone,
    required String email,
    required String password,
    required String fullName,
    required String role, // ex: jury, admin
  }) async {
    try {
      final res = await _supabase.auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: 'com.example.quranic_competition://login-callback',
        data: {'full_name': fullName, 'role': role, 'is_verified': false},
      );

      final user = res.user;
      if (user == null) {
        return 'Erreur lors de la création du compte';
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
      debugPrint(e.toString());
      return e.toString();
    }
  }

  /// Connexion avec téléphone et mot de passe.
  Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final res = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (res.user == null) {
        return 'البريد الإلكتروني أو كلمة المرور غير صحيحة';
      }

      // Initialiser les permissions après la connexion
      await _initializeUserPermissions(res.user!.id);

      return null; // Succès
    } catch (e) {
      return e.toString();
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

  /// Récupérer le profil utilisateur actuel depuis la table users.
  Future<AppUser?> getUserProfile() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    final response =
        await _supabase.from('users').select().eq('id', user.id).maybeSingle();

    if (response == null) {
      print('Profil utilisateur non trouvé');
      return null;
    }

    return AppUser.fromMap(response);
  }
}
