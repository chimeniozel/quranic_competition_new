# Nouvelle Structure: Gestion des Jurys par Round

## 🎯 Objectif

Changer la structure de gestion des jurys de :
- **Ancienne structure**: `users (jury) <-> competition_version`
- **Nouvelle structure**: `users (jury) <-> rounds`

## 🏗️ Architecture

### 1. Nouvelle Table: `round_jury_assignments`

```sql
CREATE TABLE round_jury_assignments (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    round_id UUID NOT NULL REFERENCES rounds(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Contrainte unique: un jury ne peut être assigné qu'une fois par round
    UNIQUE(user_id, round_id)
);
```

### 2. Vue: `jury_round_assignments_view`

```sql
CREATE VIEW jury_round_assignments_view AS
SELECT 
    rja.id as assignment_id,
    rja.user_id as jury_id,
    rja.round_id,
    p.full_name as jury_name,
    p.phone as jury_phone,
    p.email as jury_email,
    p.role,
    r.number as round_number,
    r.name as round_name,
    r.version_id,
    cv.name as version_name,
    cv.year as version_year,
    rja.created_at as assigned_at
FROM round_jury_assignments rja
JOIN profiles p ON rja.user_id = p.id
JOIN rounds r ON rja.round_id = r.id
JOIN competition_versions cv ON r.version_id = cv.id
WHERE p.role = 'jury';
```

## 📁 Nouveaux Fichiers

### 1. Service: `lib/core/services/round_jury_service.dart`

**Fonctionnalités principales:**
- `getJurysByRound(String roundId)` - Récupère les jurys d'un round
- `getJurysByVersion(String versionId)` - Récupère tous les jurys d'une version
- `assignJuryToRound(String juryId, String roundId)` - Assigne un jury à un round
- `removeJuryFromRound(String juryId, String roundId)` - Supprime un jury d'un round
- `isJuryAssignedToRound(String juryId, String roundId)` - Vérifie l'assignation

### 2. Page UI: `lib/features/admin/pages/competition_management/round_jurys_page.dart`

**Fonctionnalités:**
- Sélection de round avec dropdown
- Affichage des jurys assignés au round sélectionné
- Ajout/suppression de jurys par round
- Vérification des évaluations avant suppression
- Interface moderne avec Material 3

### 3. Scripts SQL

- `create_round_jury_assignments_structure.sql` - Création de la structure
- `migrate_to_round_jury_structure.sql` - Migration complète des données

## 🔄 Migration des Données

### Processus de Migration

1. **Création de la nouvelle table** `round_jury_assignments`
2. **Migration automatique** des données existantes:
   - Pour chaque `jury_assignments` existant
   - Créer une assignation pour chaque round de la version
3. **Création de la vue** pour faciliter les requêtes
4. **Vérification** des données migrées

### Exemple de Migration

```sql
-- Avant: Jury assigné à toute la version
jury_assignments: {user_id: "jury1", version_id: "version1"}

-- Après: Jury assigné à chaque round de la version
round_jury_assignments: 
  {user_id: "jury1", round_id: "round1"}
  {user_id: "jury1", round_id: "round2"}
  {user_id: "jury1", round_id: "round3"}
```

## 🎨 Interface Utilisateur

### Page de Gestion des Jurys

1. **Sélecteur de Round**: Dropdown pour choisir le round
2. **Liste des Jurys**: Affichage des jurys assignés au round sélectionné
3. **Actions**:
   - ➕ Ajouter un jury au round
   - ➖ Supprimer un jury du round (avec vérification des évaluations)

### Logique de Vérification

- **Avant suppression**: Vérifier si le jury a terminé ses évaluations
- **Si évaluations complètes**: Proposer de garder les évaluations
- **Si évaluations incomplètes**: Proposer de supprimer les évaluations

## 🔧 Mise à Jour des Services

### EvaluationService

Ajout de la méthode:
```dart
Future<List<Evaluation>> getEvaluationsByJuryInRound({
  required String juryId,
  required String roundId,
})
```

### VersionResultsPage

Mise à jour de `_checkAllEvaluationsComplete()`:
- Utilise `RoundJuryService.getJurysByRound()` au lieu de l'ancienne logique
- Vérifie les jurys assignés au round spécifique
- Plus précis et fiable

## ✅ Avantages de la Nouvelle Structure

### 1. **Flexibilité**
- Un jury peut être assigné à certains rounds seulement
- Gestion fine par round au lieu de par version entière

### 2. **Précision**
- Vérification exacte des évaluations par round
- Pas de confusion entre les rounds

### 3. **Évolutivité**
- Facile d'ajouter/supprimer des jurys par round
- Support des compétitions multi-rounds complexes

### 4. **Performance**
- Requêtes plus ciblées
- Index optimisés pour les relations round-jury

## 🚀 Instructions de Déploiement

### 1. Exécuter la Migration

```bash
# Dans votre console Supabase ou client PostgreSQL
psql -f migrate_to_round_jury_structure.sql
```

### 2. Mettre à Jour l'Application

1. **Remplacer** `version_jurys_page.dart` par `round_jurys_page.dart`
2. **Mettre à jour** les routes pour pointer vers la nouvelle page
3. **Tester** la nouvelle fonctionnalité

### 3. Vérification

- ✅ Les jurys sont assignés par round
- ✅ Les évaluations sont vérifiées correctement
- ✅ L'interface fonctionne comme attendu
- ✅ Les résultats s'affichent correctement

### 4. Nettoyage (Optionnel)

Une fois que tout fonctionne, vous pouvez supprimer l'ancienne table:
```sql
DROP TABLE IF EXISTS jury_assignments;
```

## 🎯 Résultat Final

**Maintenant, le système gère les jurys de manière granulaire par round, permettant:**
- Une assignation flexible des jurys
- Une vérification précise des évaluations
- Une interface utilisateur intuitive
- Une architecture plus robuste et évolutive

**Le problème initial est résolu**: Les évaluations sont maintenant vérifiées correctement par round, et le système détecte immédiatement si un jury n'a pas terminé ses évaluations pour un round spécifique.
