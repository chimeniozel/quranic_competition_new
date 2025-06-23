// lib/core/services/auth_service.dart

import 'package:flutter/rendering.dart';
import 'package:quranic_competition/models/app_user.dart';
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

      // Insérer dans la table users, avec phone et email
      final insertRes = await _supabase.from('users').insert({
        'id': user.id,
        'phone': phone,
        'email': email,
        'full_name': fullName,
        'role': role,
        'is_verified': false,
        'created_at': DateTime.now().toIso8601String(),
      });

      // insertRes est une liste d'objets insérés (pas null si OK)
      if (insertRes == null || (insertRes is List && insertRes.isEmpty)) {
        return 'Erreur lors de l\'insertion dans la table users';
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

      return null; // Succès
    } catch (e) {
      return e.toString();
    }
  }

  /// Déconnexion de l'utilisateur.
  Future<void> signOut() async {
    await Supabase.instance.client.auth.signOut();
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
