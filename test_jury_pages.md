# Test des Pages des Jurys - Nouvelle Structure

## 🎯 Objectif
Vérifier que les pages des jurys fonctionnent correctement avec la nouvelle structure basée sur `round_jury_assignments`.

## 📋 Pages à Tester

### 1. `jury_home_page.dart`
- ✅ **Chargement des versions** : Doit afficher les compétitions assignées au jury
- ✅ **Statistiques** : Doit calculer correctement les évaluations
- ✅ **Navigation** : Doit permettre d'accéder aux autres pages

### 2. `jury_version_page.dart`
- ✅ **Liste des versions** : Doit afficher toutes les versions assignées
- ✅ **Navigation** : Doit permettre d'accéder aux détails de chaque version

### 3. `jury_version_detail_page.dart`
- ✅ **Participants** : Doit afficher les participants selon le round sélectionné
- ✅ **Évaluations** : Doit récupérer et afficher les évaluations existantes
- ✅ **Filtres** : Doit permettre de filtrer par groupe d'âge et statut
- ✅ **Export** : Doit permettre d'exporter les évaluations

## 🔍 Logs de Debug Ajoutés

### `jury_home_page.dart`
```dart
print('🔍 JuryHomePage - User loaded: ${user?.fullName} (ID: ${user?.id})');
print('🔍 JuryHomePage - Versions loaded: ${versions.length}');
```

### `jury_version_page.dart`
```dart
print('🔍 JuryVersionPage - Chargement des versions...');
print('🔍 JuryVersionPage - Versions chargées: ${_versions.length}');
```

### `jury_version_detail_page.dart`
```dart
print('🔍 JuryVersionDetailPage - Récupération des évaluations pour jury: $juryId, version: $versionId');
print('🔍 JuryVersionDetailPage - Évaluations récupérées: ${evaluationsResponse.length}');
```

## 🧪 Étapes de Test

1. **Se connecter en tant que jury**
2. **Vérifier la page d'accueil** (`jury_home_page.dart`)
   - Les compétitions doivent s'afficher
   - Les statistiques doivent être calculées
3. **Naviguer vers la liste des versions** (`jury_version_page.dart`)
   - Toutes les versions assignées doivent être visibles
4. **Accéder aux détails d'une version** (`jury_version_detail_page.dart`)
   - Les participants doivent s'afficher selon le round
   - Les évaluations existantes doivent être marquées
   - Les filtres doivent fonctionner

## 📊 Données Attendues

### Structure de la Base de Données
```sql
-- Assignations des jurys
round_jury_assignments (user_id, round_id, created_at)

-- Rounds
rounds (id, number, version_id, name, is_active, result_is_published)

-- Versions de compétition
competition_versions (id, name, year, is_active, jury_evaluation_enabled)

-- Évaluations
evaluations (id, jury_id, participant_id, round_id, version_id, ...)
```

## ✅ Critères de Succès

- [ ] Les compétitions s'affichent dans `jury_home_page.dart`
- [ ] Les versions s'affichent dans `jury_version_page.dart`
- [ ] Les participants s'affichent dans `jury_version_detail_page.dart`
- [ ] Les évaluations existantes sont correctement marquées
- [ ] Les filtres fonctionnent correctement
- [ ] L'export des évaluations fonctionne
- [ ] Aucune erreur dans les logs

## 🐛 Problèmes Potentiels

1. **Aucune compétition affichée** : Vérifier les assignations dans `round_jury_assignments`
2. **Participants non affichés** : Vérifier la logique de filtrage par round
3. **Évaluations non marquées** : Vérifier la récupération des évaluations
4. **Erreurs de jointure** : Vérifier les relations entre les tables

## 🔧 Solutions

Si des problèmes sont détectés :
1. Consulter les logs de debug
2. Vérifier les données dans la base
3. Exécuter les scripts SQL de diagnostic
4. Corriger les assignations si nécessaire
