# 🔐 Système de Gestion des Rôles Utilisateur

## 📋 Vue d'ensemble

Le système de gestion des rôles permet de contrôler l'accès aux fonctionnalités de l'application selon trois niveaux d'administration :

- **👑 Super Admin** : Contrôle total
- **🛠️ Admin** : Permissions administratives limitées  
- **👤 Membre ordinaire** : Accès en lecture seule

## 🏗️ Architecture du Système

### 1. Modèles de Données

#### `UserRole` (lib/models/user_role.dart)
```dart
enum UserRole {
  superAdmin('super_admin', 'Super Admin', '👑'),
  admin('admin', 'Admin', '🛠️'),
  member('membre', 'Membre ordinaire', '👤');
}
```

#### `UserPermissions` (lib/models/user_role.dart)
```dart
class UserPermissions {
  final bool canCreateVersions;
  final bool canPublishContent;
  final bool canValidateAccounts;
  final bool canDelete;
  final bool canModify;
  final bool canModifyVersions;
  final bool canAssignRoles;
  final bool canViewContent;
}
```

### 2. Services

#### `PermissionService` (lib/core/services/permission_service.dart)
- Gestion centralisée des permissions
- Vérification des droits d'accès
- Initialisation et nettoyage des permissions

#### `UserManagementService` (lib/core/services/user_management_service.dart)
- CRUD des utilisateurs et rôles
- Requêtes de permissions
- Statistiques des utilisateurs

#### `ConfirmationService` (lib/core/services/confirmation_service.dart)
- Boîtes de confirmation pour actions critiques
- Dialogs spécialisés par type d'action

### 3. Widgets de Protection

#### `RoleGuard` et ses variantes (lib/core/widgets/role_guard.dart)
```dart
// Protection basique
RoleGuard(
  permissionCheck: () => PermissionService().canDelete(),
  child: DeleteButton(),
)

// Widgets spécialisés
CanDeleteGuard(child: DeleteButton())
CanModifyGuard(child: EditButton())
CanAssignRolesGuard(child: RoleManagementButton())
```

#### `RoleInfoWidget` (lib/core/widgets/role_info_widget.dart)
```dart
// Badge compact
RoleBadge()

// Informations détaillées
UserProfileRoleInfo()
```

## 🔧 Configuration et Installation

### 1. Migration de Base de Données

#### **Étape 1 : Vérifier les rôles existants**
```bash
# Dans Supabase Dashboard > SQL Editor
# Exécuter check_existing_roles.sql pour analyser les données existantes
```

#### **Étape 2 : Sauvegarde (optionnelle mais recommandée)**
```bash
# Si vous avez des données importantes dans la table profiles existante
# Exécuter backup_profiles_before_migration.sql
```

#### **Étape 3 : Migration propre**
```bash
# Exécuter create_profiles_table_migration.sql
# Ce script supprime complètement l'ancienne table et en crée une nouvelle
```

#### **Étape 4 : Restauration (si sauvegarde effectuée)**
```bash
# Si vous avez fait une sauvegarde à l'étape 2
# Exécuter restore_profiles_after_migration.sql
```

#### **Étape 5 : Vérification et nettoyage**
```bash
# 5. Tester le système (optionnel)
# Exécuter test_profiles_system.sql

# 6. Nettoyer l'ancienne structure (optionnel)
# Exécuter cleanup_old_user_roles.sql
```

#### **⚠️ Gestion des Rôles Existants**

Le système mappe automatiquement les anciens rôles vers les nouveaux :
- `jury` → `membre` (lecture seule)
- `participant` → `membre` (lecture seule)  
- `user` → `membre` (lecture seule)
- `admin` → `admin` (permissions limitées)
- `super_admin` → `super_admin` (contrôle total)

**Structure de la base de données :**
- **Table `public.profiles`** : Gère les rôles et informations utilisateur
- **Vue `public.user_profiles_view`** : Facilite les requêtes avec jointures
- **Trigger automatique** : Crée un profil pour chaque nouvel utilisateur
- **Politiques RLS** : Sécurité au niveau des lignes

**Avantages de cette approche :**
- ✅ **Séparation des responsabilités** : `auth.users` pour l'authentification, `profiles` pour les données métier
- ✅ **Flexibilité** : Ajout facile de nouveaux champs sans affecter Supabase Auth
- ✅ **Sécurité** : RLS sur la table profiles, pas d'accès direct à auth.users
- ✅ **Performance** : Index optimisés et vue matérialisée
- ✅ **Maintenance** : Structure claire et évolutive

### 2. Initialisation dans l'Application

#### Dans `main.dart` :
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialiser Supabase
  await Supabase.initialize(...);
  
  // Initialiser les permissions de l'utilisateur actuel
  await AuthService().initializeCurrentUserPermissions();
  
  runApp(MyApp());
}
```

### 3. Intégration dans les Pages

#### Dashboard Admin avec Protection :
```dart
// Section visible seulement pour Super Admin et Admin
CanCreateVersionsGuard(
  child: Column(
    children: [
      Text('إدارة نسخ المسابقة'),
      ElevatedButton(
        onPressed: () => context.push('/admin/versions'),
        child: Text('إدارة النسخ'),
      ),
    ],
  ),
)

// Section visible seulement pour Super Admin
CanAssignRolesGuard(
  child: ElevatedButton(
    onPressed: () => context.push('/admin/users'),
    child: Text('إدارة المستخدمين'),
  ),
)
```

#### Actions avec Confirmation :
```dart
// Suppression avec confirmation
ElevatedButton(
  onPressed: () async {
    final confirmed = await ConfirmationService.showDeleteConfirmation(
      context,
      title: 'تأكيد الحذف',
      message: 'هل أنت متأكد من الحذف؟',
    );
    
    if (confirmed) {
      // Exécuter la suppression
    }
  },
  child: Text('حذف'),
)
```

## 📊 Matrice des Permissions

| Fonctionnalité | Super Admin | Admin | Membre |
|----------------|-------------|-------|---------|
| **Créer des versions** | ✅ | ✅ | ❌ |
| **Publier du contenu** | ✅ | ✅ | ❌ |
| **Valider les comptes** | ✅ | ✅ | ❌ |
| **Supprimer** | ✅ | ❌ | ❌ |
| **Modifier** | ✅ | ❌ | ❌ |
| **Modifier les versions** | ✅ | ❌ | ❌ |
| **Assigner des rôles** | ✅ | ❌ | ❌ |
| **Voir le contenu** | ✅ | ✅ | ✅ |

## 🎯 Cas d'Usage

### 1. Super Admin
- Contrôle total sur l'application
- Peut gérer tous les utilisateurs et leurs rôles
- Accès à toutes les fonctionnalités
- Actions critiques avec confirmations spéciales

### 2. Admin
- Peut créer et publier du contenu
- Peut valider les comptes
- **Ne peut pas** supprimer ou modifier
- **Ne peut pas** gérer les rôles
- Interface adaptée sans options sensibles

### 3. Membre ordinaire
- Accès en lecture seule
- Interface simplifiée
- Pas d'options d'administration
- Message informatif sur les limitations

## 🔒 Sécurité

### 1. Protection Frontend
- Widgets `RoleGuard` pour masquer/afficher les éléments
- Vérifications dans les callbacks d'actions
- Boîtes de confirmation pour actions critiques

### 2. Protection Backend
- Fonctions SQL avec vérification des rôles
- Politiques RLS (Row Level Security)
- Validation des permissions côté serveur

### 3. Gestion des Sessions
- Initialisation automatique des permissions à la connexion
- Nettoyage des permissions à la déconnexion
- Persistance des rôles dans la session

## 📱 Interface Utilisateur

### 1. Dashboard Admin
- **Badge de rôle** dans l'AppBar
- **Sections conditionnelles** selon les permissions
- **Couleurs différenciées** par type de fonctionnalité
- **Message informatif** pour les membres ordinaires

### 2. Gestion des Médias
- **Menu contextuel** avec options filtrées selon le rôle
- **Confirmations** pour actions de suppression
- **Indicateurs visuels** des permissions

### 3. Gestion des Utilisateurs
- **Liste complète** des utilisateurs avec rôles
- **Statistiques** par rôle
- **Filtres** par rôle et recherche
- **Changement de rôles** avec confirmation

## 🚀 Fonctionnalités Avancées

### 1. Statistiques
- Comptage des utilisateurs par rôle
- Taux de validation des comptes
- Métriques d'utilisation

### 2. Recherche et Filtrage
- Recherche par email
- Filtrage par rôle
- Tri par date de création

### 3. Gestion des Sessions
- Détection automatique des changements de rôles
- Mise à jour en temps réel des permissions
- Gestion des erreurs de permissions

## 🛠️ Maintenance et Développement

### 1. Ajout de Nouveaux Rôles
1. Ajouter l'enum dans `UserRole`
2. Mettre à jour `UserPermissions.forRole()`
3. Ajouter les widgets de protection
4. Mettre à jour la base de données

### 2. Ajout de Nouvelles Permissions
1. Ajouter le champ dans `UserPermissions`
2. Mettre à jour la logique dans `PermissionService`
3. Créer un widget de protection spécialisé
4. Mettre à jour la base de données

### 3. Debug et Logs
- Logs automatiques des initialisations de permissions
- Messages d'erreur détaillés
- Indicateurs visuels des permissions actives

## 📝 Notes Importantes

1. **Sécurité** : Toujours vérifier les permissions côté backend
2. **UX** : Masquer les éléments non accessibles plutôt que les désactiver
3. **Performance** : Cache des permissions pour éviter les requêtes répétées
4. **Maintenance** : Documenter toute modification des rôles ou permissions

## 🔄 Prochaines Étapes

- [ ] Intégration avec la gestion des versions
- [ ] Audit trail des actions administratives
- [ ] Notifications pour changements de rôles
- [ ] Interface de création d'utilisateurs
- [ ] Export des statistiques utilisateurs
