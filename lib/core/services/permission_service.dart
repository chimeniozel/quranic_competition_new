import 'package:quranic_competition/models/user_role.dart';

class PermissionService {
  static final PermissionService _instance = PermissionService._internal();
  factory PermissionService() => _instance;
  PermissionService._internal();

  UserRole? _currentUserRole;
  UserPermissions? _currentPermissions;

  // Initialiser le rôle de l'utilisateur actuel
  void setUserRole(UserRole role, {UserPermissions? customPermissions}) {
    _currentUserRole = role;
    _currentPermissions = customPermissions ?? UserPermissions.forRole(role);
  }

  void updatePermissions(UserPermissions permissions) {
    _currentPermissions = permissions;
  }

  // Récupérer le rôle actuel
  UserRole? get currentUserRole => _currentUserRole;
  UserPermissions? get currentPermissions => _currentPermissions;

  // Vérifier si l'utilisateur peut créer des versions
  bool canCreateVersions() {
    return _currentPermissions?.canCreateVersions ?? false;
  }

  // Vérifier si l'utilisateur peut publier du contenu
  bool canPublishContent() {
    return _currentPermissions?.canPublishContent ?? false;
  }

  // Vérifier si l'utilisateur peut valider des comptes
  bool canValidateAccounts() {
    return _currentPermissions?.canValidateAccounts ?? false;
  }

  // Vérifier si l'utilisateur peut supprimer
  bool canDelete() {
    return _currentPermissions?.canDelete ?? false;
  }

  // Vérifier si l'utilisateur peut modifier
  bool canModify() {
    return _currentPermissions?.canModify ?? false;
  }

  // Vérifier si l'utilisateur peut modifier les versions
  bool canModifyVersions() {
    return _currentPermissions?.canModifyVersions ?? false;
  }

  // Vérifier si l'utilisateur peut assigner des rôles
  bool canAssignRoles() {
    return _currentPermissions?.canAssignRoles ?? false;
  }

  // Vérifier si l'utilisateur peut voir le contenu
  bool canViewContent() {
    return _currentPermissions?.canViewContent ?? false;
  }

  // Vérifier si l'utilisateur est Super Admin
  bool isSuperAdmin() {
    return _currentUserRole == UserRole.superAdmin;
  }

  // Vérifier si l'utilisateur est Admin
  bool isAdmin() {
    return _currentUserRole == UserRole.admin;
  }

  // Vérifier si l'utilisateur est Jury
  bool isJury() {
    return _currentUserRole == UserRole.jury;
  }

  // Vérifier si l'utilisateur est un membre ordinaire
  bool isMember() {
    return _currentUserRole == UserRole.member;
  }

  // Vérifier si l'utilisateur a des permissions administratives
  bool hasAdminPermissions() {
    return isSuperAdmin() || isAdmin();
  }

  // Réinitialiser les permissions (pour la déconnexion)
  void clearPermissions() {
    _currentUserRole = null;
    _currentPermissions = null;
  }

  // Obtenir le nom d'affichage du rôle
  String getRoleDisplayName() {
    return _currentUserRole?.displayName ?? 'Membre ordinaire';
  }
}
