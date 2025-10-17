-- Script pour corriger la relation entre jury_assignments et profiles
-- Le problème: jury_assignments référence users au lieu de profiles

-- 1. Vérifier la structure actuelle de la table jury_assignments
SELECT 
    column_name, 
    data_type, 
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'jury_assignments' 
AND table_schema = 'public'
ORDER BY ordinal_position;

-- 2. Vérifier les contraintes de clé étrangère existantes
SELECT 
    tc.constraint_name,
    tc.table_name,
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
    AND tc.table_schema = kcu.table_schema
JOIN information_schema.constraint_column_usage AS ccu
    ON ccu.constraint_name = tc.constraint_name
    AND ccu.table_schema = tc.table_schema
WHERE tc.constraint_type = 'FOREIGN KEY'
    AND tc.table_name = 'jury_assignments'
    AND tc.table_schema = 'public';

-- 3. Supprimer l'ancienne contrainte vers users (si elle existe)
DO $$
BEGIN
    -- Vérifier si la contrainte vers users existe
    IF EXISTS (
        SELECT 1 
        FROM information_schema.table_constraints 
        WHERE constraint_name LIKE '%user_id%'
        AND table_name = 'jury_assignments'
        AND table_schema = 'public'
        AND constraint_type = 'FOREIGN KEY'
    ) THEN
        -- Trouver le nom exact de la contrainte
        DECLARE
            constraint_name_var TEXT;
        BEGIN
            SELECT tc.constraint_name INTO constraint_name_var
            FROM information_schema.table_constraints tc
            JOIN information_schema.key_column_usage kcu
                ON tc.constraint_name = kcu.constraint_name
            WHERE tc.table_name = 'jury_assignments'
                AND tc.table_schema = 'public'
                AND tc.constraint_type = 'FOREIGN KEY'
                AND kcu.column_name = 'user_id';
            
            -- Supprimer la contrainte
            EXECUTE 'ALTER TABLE jury_assignments DROP CONSTRAINT ' || constraint_name_var;
            RAISE NOTICE 'Ancienne contrainte supprimée: %', constraint_name_var;
        END;
    ELSE
        RAISE NOTICE 'Aucune contrainte user_id trouvée à supprimer';
    END IF;
END $$;

-- 4. Vérifier que la colonne user_id pointe vers profiles.id
-- Si user_id pointe vers auth.users, nous devons la modifier
DO $$
BEGIN
    -- Vérifier si user_id est de type UUID et compatible avec profiles.id
    IF EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_name = 'jury_assignments' 
        AND column_name = 'user_id' 
        AND data_type = 'uuid'
        AND table_schema = 'public'
    ) THEN
        RAISE NOTICE 'La colonne user_id est déjà de type UUID - OK';
    ELSE
        RAISE NOTICE 'La colonne user_id doit être convertie en UUID';
        -- Convertir la colonne en UUID si nécessaire
        ALTER TABLE jury_assignments 
        ALTER COLUMN user_id TYPE UUID USING user_id::UUID;
    END IF;
END $$;

-- 5. Ajouter la nouvelle contrainte vers profiles
DO $$
BEGIN
    -- Vérifier si la contrainte vers profiles existe déjà
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.table_constraints 
        WHERE constraint_name = 'jury_assignments_user_id_fkey'
        AND table_name = 'jury_assignments'
        AND table_schema = 'public'
    ) THEN
        -- Ajouter la contrainte de clé étrangère pour user_id -> profiles.id
        ALTER TABLE jury_assignments 
        ADD CONSTRAINT jury_assignments_user_id_fkey 
        FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE;
        
        RAISE NOTICE 'Nouvelle contrainte user_id -> profiles.id ajoutée';
    ELSE
        RAISE NOTICE 'Contrainte user_id -> profiles.id existe déjà';
    END IF;
END $$;

-- 6. Vérifier et corriger la contrainte version_id
DO $$
BEGIN
    -- Vérifier si la contrainte version_id existe
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.table_constraints 
        WHERE constraint_name = 'jury_assignments_version_id_fkey'
        AND table_name = 'jury_assignments'
        AND table_schema = 'public'
    ) THEN
        -- Ajouter la contrainte de clé étrangère pour version_id
        ALTER TABLE jury_assignments 
        ADD CONSTRAINT jury_assignments_version_id_fkey 
        FOREIGN KEY (version_id) REFERENCES competition_versions(id) ON DELETE CASCADE;
        
        RAISE NOTICE 'Contrainte version_id -> competition_versions.id ajoutée';
    ELSE
        RAISE NOTICE 'Contrainte version_id -> competition_versions.id existe déjà';
    END IF;
END $$;

-- 7. Créer les index pour améliorer les performances
CREATE INDEX IF NOT EXISTS idx_jury_assignments_version_id ON jury_assignments(version_id);
CREATE INDEX IF NOT EXISTS idx_jury_assignments_user_id ON jury_assignments(user_id);

-- 8. Vérifier les données existantes et nettoyer si nécessaire
SELECT 
    ja.id,
    ja.user_id,
    ja.version_id,
    p.full_name,
    p.role,
    cv.name as version_name,
    CASE 
        WHEN p.id IS NULL THEN 'PROFIL MANQUANT'
        WHEN cv.id IS NULL THEN 'VERSION MANQUANTE'
        ELSE 'OK'
    END as status
FROM jury_assignments ja
LEFT JOIN profiles p ON ja.user_id = p.id
LEFT JOIN competition_versions cv ON ja.version_id = cv.id
ORDER BY ja.created_at DESC;

-- 9. Nettoyer les données orphelines (optionnel - à exécuter avec précaution)
-- ATTENTION: Cette commande supprime les assignments vers des profils inexistants
-- Décommentez seulement si vous voulez nettoyer les données
/*
DELETE FROM jury_assignments 
WHERE user_id NOT IN (SELECT id FROM profiles)
OR version_id NOT IN (SELECT id FROM competition_versions);
*/

-- 10. Vérification finale des contraintes
SELECT 
    tc.constraint_name,
    tc.table_name,
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
    AND tc.table_schema = kcu.table_schema
JOIN information_schema.constraint_column_usage AS ccu
    ON ccu.constraint_name = tc.constraint_name
    AND ccu.table_schema = tc.table_schema
WHERE tc.constraint_type = 'FOREIGN KEY'
    AND tc.table_name = 'jury_assignments'
    AND tc.table_schema = 'public'
ORDER BY tc.constraint_name;
