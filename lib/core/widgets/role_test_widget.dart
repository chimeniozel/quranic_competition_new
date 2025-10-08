import 'package:flutter/material.dart';
import 'package:quranic_competition/core/services/permission_service.dart';
import 'package:quranic_competition/core/widgets/role_guard.dart';
import 'package:quranic_competition/core/widgets/role_info_widget.dart';
import 'package:quranic_competition/models/user_role.dart';

/// Widget de test pour démontrer le système de rôles
/// À utiliser uniquement en développement
class RoleTestWidget extends StatelessWidget {
  const RoleTestWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test du Système de Rôles'),
        backgroundColor: Colors.purple[600],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Informations sur le rôle actuel
            const UserProfileRoleInfo(),
            const SizedBox(height: 24),

            // Test des permissions
            const Text(
              'Test des Permissions',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Boutons de test pour chaque permission
            _buildPermissionTestButton(
              'Créer des versions',
              Icons.add_circle,
              Colors.blue,
              () => PermissionService().canCreateVersions(),
            ),
            const SizedBox(height: 8),

            _buildPermissionTestButton(
              'Publier du contenu',
              Icons.publish,
              Colors.green,
              () => PermissionService().canPublishContent(),
            ),
            const SizedBox(height: 8),

            _buildPermissionTestButton(
              'Valider les comptes',
              Icons.verified_user,
              Colors.orange,
              () => PermissionService().canValidateAccounts(),
            ),
            const SizedBox(height: 8),

            _buildPermissionTestButton(
              'Supprimer',
              Icons.delete,
              Colors.red,
              () => PermissionService().canDelete(),
            ),
            const SizedBox(height: 8),

            _buildPermissionTestButton(
              'Modifier',
              Icons.edit,
              Colors.blue,
              () => PermissionService().canModify(),
            ),
            const SizedBox(height: 8),

            _buildPermissionTestButton(
              'Modifier les versions',
              Icons.update,
              Colors.purple,
              () => PermissionService().canModifyVersions(),
            ),
            const SizedBox(height: 8),

            _buildPermissionTestButton(
              'Assigner des rôles',
              Icons.admin_panel_settings,
              Colors.teal,
              () => PermissionService().canAssignRoles(),
            ),
            const SizedBox(height: 8),

            _buildPermissionTestButton(
              'Voir le contenu',
              Icons.visibility,
              Colors.grey,
              () => PermissionService().canViewContent(),
            ),
            const SizedBox(height: 24),

            // Test des widgets de protection
            const Text(
              'Test des Widgets de Protection',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Widgets protégés
            CanCreateVersionsGuard(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  border: Border.all(color: Colors.blue[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.add_circle, color: Colors.blue),
                    SizedBox(width: 8),
                    Text(
                      'Ce bouton est visible seulement si vous pouvez créer des versions',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),

            CanDeleteGuard(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  border: Border.all(color: Colors.red[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.delete, color: Colors.red),
                    SizedBox(width: 8),
                    Text(
                      'Ce bouton est visible seulement pour les Super Admins',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),

            CanAssignRolesGuard(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.purple[50],
                  border: Border.all(color: Colors.purple[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.admin_panel_settings, color: Colors.purple),
                    SizedBox(width: 8),
                    Text(
                      'Ce bouton est visible seulement pour les Super Admins',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Boutons de simulation de rôles (pour les tests)
            const Text(
              'Simulation de Rôles (Développement)',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _simulateRole(UserRole.superAdmin),
                    child: const Text('Super Admin'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple[600],
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _simulateRole(UserRole.admin),
                    child: const Text('Admin'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[600],
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _simulateRole(UserRole.member),
                    child: const Text('Membre'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[600],
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionTestButton(
    String title,
    IconData icon,
    Color color,
    bool Function() permissionCheck,
  ) {
    final hasPermission = permissionCheck();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: hasPermission ? color.withOpacity(0.1) : Colors.grey[100],
        border: Border.all(color: hasPermission ? color : Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: hasPermission ? color : Colors.grey[400], size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: hasPermission ? color : Colors.grey[600],
                fontWeight: hasPermission ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
          Icon(
            hasPermission ? Icons.check_circle : Icons.cancel,
            color: hasPermission ? Colors.green : Colors.red,
            size: 20,
          ),
        ],
      ),
    );
  }

  void _simulateRole(UserRole role) {
    PermissionService().setUserRole(role);

    // Note: Dans un vrai scénario, vous devriez rediriger ou reconstruire le widget
    // Pour ce test, nous utilisons seulement le service
    print('🎭 Rôle simulé: ${role.displayName}');
  }
}
