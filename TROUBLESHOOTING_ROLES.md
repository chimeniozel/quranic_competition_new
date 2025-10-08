# 🔧 Guide de Dépannage - Système de Rôles

## 🚨 Erreurs Courantes et Solutions

### **Erreur : `violates check constraint "profiles_role_check"`**

**Symptôme :**
```
ERROR: 23514: new row for relation "profiles" violates check constraint "profiles_role_check"
DETAIL: Failing row contains (..., jury, ...)
```

**Cause :** Votre base de données contient des utilisateurs avec des rôles non standard (jury, participant, etc.)

**Solution :**
1. **Exécuter le diagnostic :**
   ```sql
   -- Exécuter check_existing_roles.sql
   ```

2. **Utiliser la migration adaptée :**
   ```sql
   -- Exécuter fix_existing_roles_migration.sql au lieu de create_profiles_table_migration.sql
   ```

3. **Vérifier les résultats :**
   ```sql
   -- Exécuter test_profiles_system.sql
   ```

---

### **Erreur : `relation "profiles" already exists`**

**Symptôme :**
```
ERROR: 42P07: relation "profiles" already exists
```

**Cause :** La table profiles existe déjà

**Solution :**
1. **Vérifier l'état actuel :**
   ```sql
   SELECT COUNT(*) FROM public.profiles;
   SELECT role, COUNT(*) FROM public.profiles GROUP BY role;
   ```

2. **Si la table est vide ou corrompue :**
   ```sql
   -- Utiliser rollback_profiles_migration.sql puis relancer la migration
   ```

3. **Si la table contient des données valides :**
   ```sql
   -- Continuer avec test_profiles_system.sql
   ```

---

### **Erreur : `permission denied for table profiles`**

**Symptôme :**
```
ERROR: 42501: permission denied for table profiles
```

**Cause :** Problème de permissions RLS

**Solution :**
1. **Vérifier les politiques RLS :**
   ```sql
   SELECT * FROM pg_policies WHERE tablename = 'profiles';
   ```

2. **Recréer les politiques :**
   ```sql
   -- Relancer la partie politique de create_profiles_table_migration.sql
   ```

---

### **Erreur : `function user_has_permission does not exist`**

**Symptôme :**
```
ERROR: 42883: function user_has_permission(uuid, text) does not exist
```

**Cause :** Les fonctions de permissions n'ont pas été créées

**Solution :**
1. **Vérifier les fonctions :**
   ```sql
   SELECT proname FROM pg_proc WHERE proname LIKE '%permission%';
   ```

2. **Recréer les fonctions :**
   ```sql
   -- Relancer la partie fonctions de create_profiles_table_migration.sql
   ```

---

## 🔍 Diagnostics

### **Vérifier l'état de la migration**

```sql
-- 1. Vérifier si la table profiles existe
SELECT EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_name = 'profiles'
);

-- 2. Compter les utilisateurs migrés
SELECT COUNT(*) as profiles_count FROM public.profiles;
SELECT COUNT(*) as auth_users_count FROM auth.users;

-- 3. Vérifier les rôles
SELECT role, COUNT(*) FROM public.profiles GROUP BY role;

-- 4. Tester les fonctions
SELECT public.user_has_permission(
    (SELECT id FROM public.profiles LIMIT 1), 
    'view_content'
);
```

### **Vérifier les triggers**

```sql
-- Vérifier si le trigger existe
SELECT tgname FROM pg_trigger WHERE tgname = 'on_auth_user_created';

-- Tester la création d'un utilisateur (simulation)
-- (Ceci ne créera pas vraiment d'utilisateur)
```

### **Vérifier les politiques RLS**

```sql
-- Lister toutes les politiques
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual
FROM pg_policies 
WHERE tablename = 'profiles';
```

---

## 🛠️ Procédures de Récupération

### **Récupération Complète**

Si tout va mal, suivez cette procédure :

1. **Sauvegarder les données importantes :**
   ```sql
   -- Sauvegarder les utilisateurs existants
   SELECT id, email, raw_user_meta_data FROM auth.users;
   ```

2. **Rollback complet :**
   ```sql
   -- Exécuter rollback_profiles_migration.sql
   ```

3. **Migration propre :**
   ```sql
   -- Exécuter check_existing_roles.sql
   -- Puis fix_existing_roles_migration.sql ou create_profiles_table_migration.sql
   ```

4. **Vérification :**
   ```sql
   -- Exécuter test_profiles_system.sql
   ```

### **Récupération Partielle**

Si seuls certains éléments posent problème :

1. **Problème avec les fonctions :**
   ```sql
   -- Supprimer et recréer les fonctions
   DROP FUNCTION IF EXISTS public.user_has_permission(UUID, TEXT);
   DROP FUNCTION IF EXISTS public.get_user_permissions(UUID);
   -- Puis relancer la partie fonctions de la migration
   ```

2. **Problème avec les politiques :**
   ```sql
   -- Supprimer et recréer les politiques
   DROP POLICY IF EXISTS "Users can view own profile" ON public.profiles;
   DROP POLICY IF EXISTS "Super admins can view all profiles" ON public.profiles;
   DROP POLICY IF EXISTS "Super admins can update all profiles" ON public.profiles;
   DROP POLICY IF EXISTS "Super admins can insert profiles" ON public.profiles;
   -- Puis relancer la partie politiques de la migration
   ```

---

## 📋 Checklist de Vérification

Après migration, vérifiez que tout fonctionne :

- [ ] Table `profiles` créée
- [ ] Vue `user_profiles_view` fonctionnelle
- [ ] Fonctions de permissions créées
- [ ] Triggers automatiques actifs
- [ ] Politiques RLS en place
- [ ] Utilisateurs existants migrés
- [ ] Rôles mappés correctement
- [ ] Application Flutter fonctionne

---

## 🆘 Support

Si vous rencontrez d'autres problèmes :

1. **Vérifiez les logs Supabase** pour plus de détails
2. **Utilisez les scripts de diagnostic** fournis
3. **Consultez la documentation** Supabase sur RLS
4. **Testez étape par étape** plutôt que tout d'un coup

---

## 📞 Contact

Pour des problèmes spécifiques à votre implémentation, fournissez :
- Message d'erreur complet
- Résultats de `check_existing_roles.sql`
- Version de Supabase utilisée
- Logs de l'application Flutter
