# Fix pour le problème des jurys non affichés

## Problème identifié

L'erreur suivante se produit lors du chargement des jurys :
```
PostgrestException(message: Could not find a relationship between 'jury_assignments' and 'profiles' in the schema cache, code: PGRST200, details: Searched for a foreign key relationship between 'jury_assignments' and 'profiles' in the schema 'public', but no matches were found., hint: null)
```

## Cause du problème

La table `jury_assignments` a une relation de clé étrangère avec la table `users` (auth.users) au lieu de la table `profiles`, ce qui empêche Supabase de faire des jointures automatiques avec `profiles(*)`.

## Solution

### 1. Script SQL de correction

Le fichier `fix_jury_assignments_relation.sql` contient un script pour :
- Supprimer l'ancienne contrainte vers `users`
- Ajouter la nouvelle contrainte vers `profiles`
- Vérifier et corriger la structure des données
- Créer les index nécessaires

### 2. Instructions de résolution

**Exécuter le script SQL :**
1. Ouvrez votre console Supabase ou votre client PostgreSQL
2. Exécutez le contenu du fichier `fix_jury_assignments_relation.sql`
3. Vérifiez que les nouvelles contraintes ont été créées

### 3. Vérification manuelle

Pour vérifier que la correction a fonctionné :

```sql
-- Vérifier les contraintes de clé étrangère
SELECT 
    tc.constraint_name,
    tc.table_name,
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage AS ccu
    ON ccu.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
    AND tc.table_name = 'jury_assignments';
```

### 4. Structure attendue après correction

```sql
-- Contraintes attendues
jury_assignments_user_id_fkey: user_id -> profiles(id)
jury_assignments_version_id_fkey: version_id -> competition_versions(id)
```

### 5. Test de la solution

Une fois le script exécuté, la méthode `getJurysByVersion` devrait :
1. Essayer la jointure `profiles(*)` (qui devrait maintenant fonctionner)
2. Si elle échoue, utiliser la méthode alternative en deux étapes

Les logs devraient montrer :
```
✅ Jointure réussie: X jurys trouvés
```

Au lieu de :
```
⚠️ Jointure échouée: PostgrestException...
```

## Notes importantes

- Le script préserve les données existantes
- Il nettoie automatiquement les références orphelines
- La méthode de contournement reste en place pour la robustesse
- Une fois corrigé, les performances seront optimales