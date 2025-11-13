import 'package:quranic_competition/models/user_role.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PermissionService {
  static final PermissionService _instance = PermissionService._internal();
  factory PermissionService() => _instance;
  PermissionService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;

  // Cache pour éviter les appels répétés à la DB dans la même requête
  UserRole? _cachedRole;
  UserPermissions? _cachedPermissions;
  String? _cachedUserId;

  /// Récupère le rôle et les permissions depuis la base de données (source de vérité)
  Future<Map<String, dynamic>?> _getRoleAndPermissionsFromDB() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return null;

      // Utiliser le cache si l'utilisateur est le même
      if (_cachedUserId == userId && _cachedRole != null && _cachedPermissions != null) {
        return {
          'role': _cachedRole,
          'permissions': _cachedPermissions,
        };
      }

      // Récupérer le rôle et les permissions en une seule requête
      final response = await _supabase
          .from('profiles')
          .select(
            'role, can_create_versions, can_publish_content, '
            'can_validate_accounts, can_delete, can_modify, '
            'can_modify_versions, can_assign_roles, can_view_content',
          )
          .eq('id', userId)
          .maybeSingle();

      if (response == null) return null;

      final roleCode = response['role'] as String?;
      if (roleCode == null) return null;

      final role = UserRole.fromString(roleCode);
      final basePermissions = UserPermissions.forRole(role);
      
      // Utiliser les permissions de la DB si disponibles, sinon utiliser les permissions par défaut
      UserPermissions permissions = basePermissions;
      
      // Vérifier si les colonnes de permissions existent (non null)
      final hasCustomPermissions = response['can_create_versions'] != null ||
          response['can_publish_content'] != null ||
          response['can_validate_accounts'] != null;
      
      if (hasCustomPermissions) {
        permissions = UserPermissions.withOverrides(basePermissions, response);
      }

      // Mettre à jour le cache
      _cachedRole = role;
      _cachedPermissions = permissions;
      _cachedUserId = userId;

      return {
        'role': role,
        'permissions': permissions,
      };
    } catch (e) {
      print('Erreur lors de la récupération des permissions: $e');
      return null;
    }
  }

  // Initialiser le rôle de l'utilisateur actuel (pour compatibilité)
  void setUserRole(UserRole role, {UserPermissions? customPermissions}) {
    _cachedRole = role;
    _cachedPermissions = customPermissions ?? UserPermissions.forRole(role);
    _cachedUserId = _supabase.auth.currentUser?.id;
  }

  void updatePermissions(UserPermissions permissions) {
    _cachedPermissions = permissions;
  }

  // Récupérer le rôle actuel depuis la DB
  Future<UserRole?> get currentUserRole async {
    final data = await _getRoleAndPermissionsFromDB();
    return data?['role'] as UserRole?;
  }

  // Récupérer les permissions actuelles depuis la DB
  Future<UserPermissions?> get currentPermissions async {
    final data = await _getRoleAndPermissionsFromDB();
    return data?['permissions'] as UserPermissions?;
  }

  // Vérifier si l'utilisateur peut créer des versions
  Future<bool> canCreateVersions() async {
    final permissions = await currentPermissions;
    return permissions?.canCreateVersions ?? false;
  }

  // Vérifier si l'utilisateur peut publier du contenu
  Future<bool> canPublishContent() async {
    final permissions = await currentPermissions;
    return permissions?.canPublishContent ?? false;
  }

  // Vérifier si l'utilisateur peut valider des comptes
  Future<bool> canValidateAccounts() async {
    final permissions = await currentPermissions;
    return permissions?.canValidateAccounts ?? false;
  }

  // Vérifier si l'utilisateur peut supprimer
  Future<bool> canDelete() async {
    final permissions = await currentPermissions;
    return permissions?.canDelete ?? false;
  }

  // Vérifier si l'utilisateur peut modifier
  Future<bool> canModify() async {
    final permissions = await currentPermissions;
    return permissions?.canModify ?? false;
  }

  // Vérifier si l'utilisateur peut modifier les versions
  Future<bool> canModifyVersions() async {
    final permissions = await currentPermissions;
    return permissions?.canModifyVersions ?? false;
  }

  // Vérifier si l'utilisateur peut assigner des rôles
  Future<bool> canAssignRoles() async {
    final permissions = await currentPermissions;
    return permissions?.canAssignRoles ?? false;
  }

  // Vérifier si l'utilisateur peut voir le contenu
  Future<bool> canViewContent() async {
    final permissions = await currentPermissions;
    return permissions?.canViewContent ?? false;
  }

  // Vérifier si l'utilisateur est Super Admin
  Future<bool> isSuperAdmin() async {
    final role = await currentUserRole;
    return role == UserRole.superAdmin;
  }

  // Vérifier si l'utilisateur est Admin
  Future<bool> isAdmin() async {
    final role = await currentUserRole;
    return role == UserRole.admin;
  }

  // Vérifier si l'utilisateur est Jury
  Future<bool> isJury() async {
    final role = await currentUserRole;
    return role == UserRole.jury;
  }

  // Vérifier si l'utilisateur est un membre ordinaire
  Future<bool> isMember() async {
    final role = await currentUserRole;
    return role == UserRole.member;
  }

  // Vérifier si l'utilisateur a des permissions administratives
  Future<bool> hasAdminPermissions() async {
    final isSuper = await isSuperAdmin();
    final isAdm = await isAdmin();
    return isSuper || isAdm;
  }

  // Réinitialiser les permissions (pour la déconnexion)
  void clearPermissions() {
    _cachedRole = null;
    _cachedPermissions = null;
    _cachedUserId = null;
  }

  // Forcer le rafraîchissement des permissions depuis la DB
  Future<void> refreshPermissions() async {
    _cachedRole = null;
    _cachedPermissions = null;
    _cachedUserId = null;
    await _getRoleAndPermissionsFromDB();
  }

  // Obtenir le nom d'affichage du rôle
  Future<String> getRoleDisplayName() async {
    final role = await currentUserRole;
    return role?.displayName ?? 'Membre ordinaire';
  }

  // Méthode synchrone pour compatibilité (utilise le cache)
  // ⚠️ À utiliser uniquement si les permissions ont déjà été chargées
  UserRole? get currentUserRoleSync => _cachedRole;
  UserPermissions? get currentPermissionsSync => _cachedPermissions;
  
  // Méthodes synchrones pour compatibilité (utilisent le cache)
  bool canCreateVersionsSync() => _cachedPermissions?.canCreateVersions ?? false;
  bool canPublishContentSync() => _cachedPermissions?.canPublishContent ?? false;
  bool canValidateAccountsSync() => _cachedPermissions?.canValidateAccounts ?? false;
  bool canDeleteSync() => _cachedPermissions?.canDelete ?? false;
  bool canModifySync() => _cachedPermissions?.canModify ?? false;
  bool canModifyVersionsSync() => _cachedPermissions?.canModifyVersions ?? false;
  bool canAssignRolesSync() => _cachedPermissions?.canAssignRoles ?? false;
  bool canViewContentSync() => _cachedPermissions?.canViewContent ?? false;
  bool isSuperAdminSync() => _cachedRole == UserRole.superAdmin;
  bool isAdminSync() => _cachedRole == UserRole.admin;
  bool isJurySync() => _cachedRole == UserRole.jury;
  bool isMemberSync() => _cachedRole == UserRole.member;
  bool hasAdminPermissionsSync() => isSuperAdminSync() || isAdminSync();
  String getRoleDisplayNameSync() => _cachedRole?.displayName ?? 'Membre ordinaire';
}
