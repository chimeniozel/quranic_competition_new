-- Script de migration complet vers la nouvelle structure round_jury_assignments
-- Ce script migre de: users (jury) <-> competition_version
-- Vers: users (jury) <-> rounds

-- ========================================
-- ÉTAPE 1: Créer la nouvelle structure
-- ========================================

-- 1. Créer la nouvelle table round_jury_assignments
CREATE TABLE IF NOT EXISTS round_jury_assignments (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    round_id UUID NOT NULL REFERENCES rounds(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Contrainte unique: un jury ne peut être assigné qu'une fois par round
    UNIQUE(user_id, round_id)
);

-- 2. Créer les index pour améliorer les performances
CREATE INDEX IF NOT EXISTS idx_round_jury_assignments_user_id ON round_jury_assignments(user_id);
CREATE INDEX IF NOT EXISTS idx_round_jury_assignments_round_id ON round_jury_assignments(round_id);
CREATE INDEX IF NOT EXISTS idx_round_jury_assignments_created_at ON round_jury_assignments(created_at);

-- 3. Ajouter les contraintes de clé étrangère explicites
DO $$
BEGIN
    -- Contrainte user_id -> profiles(id)
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'round_jury_assignments_user_id_fkey'
        AND table_name = 'round_jury_assignments'
    ) THEN
        ALTER TABLE round_jury_assignments 
        ADD CONSTRAINT round_jury_assignments_user_id_fkey 
        FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE;
        RAISE NOTICE 'Contrainte user_id -> profiles(id) ajoutée';
    END IF;

    -- Contrainte round_id -> rounds(id)
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'round_jury_assignments_round_id_fkey'
        AND table_name = 'round_jury_assignments'
    ) THEN
        ALTER TABLE round_jury_assignments 
        ADD CONSTRAINT round_jury_assignments_round_id_fkey 
        FOREIGN KEY (round_id) REFERENCES rounds(id) ON DELETE CASCADE;
        RAISE NOTICE 'Contrainte round_id -> rounds(id) ajoutée';
    END IF;
END $$;

-- ========================================
-- ÉTAPE 2: Migrer les données existantes
-- ========================================

-- Fonction de migration
CREATE OR REPLACE FUNCTION migrate_jury_assignments_to_rounds()
RETURNS void AS $$
DECLARE
    assignment_record RECORD;
    round_record RECORD;
    migration_count INTEGER := 0;
BEGIN
    RAISE NOTICE 'Début de la migration des assignations de jurys...';
    
    -- Pour chaque assignment existant dans jury_assignments
    FOR assignment_record IN 
        SELECT ja.user_id, ja.version_id, ja.created_at
        FROM jury_assignments ja
        WHERE ja.user_id IS NOT NULL 
        AND ja.version_id IS NOT NULL
    LOOP
        RAISE NOTICE 'Migration du jury % pour la version %', 
            assignment_record.user_id, assignment_record.version_id;
        
        -- Trouver tous les rounds de cette version
        FOR round_record IN 
            SELECT r.id, r.number, r.name
            FROM rounds r
            WHERE r.version_id = assignment_record.version_id
            ORDER BY r.number
        LOOP
            -- Insérer l'assignment pour ce round (si pas déjà existant)
            INSERT INTO round_jury_assignments (user_id, round_id, created_at)
            VALUES (assignment_record.user_id, round_record.id, assignment_record.created_at)
            ON CONFLICT (user_id, round_id) DO NOTHING;
            
            migration_count := migration_count + 1;
            RAISE NOTICE '  ✓ Jury assigné au round % (%)', 
                round_record.number, 
                COALESCE(round_record.name, 'Sans nom');
        END LOOP;
    END LOOP;
    
    RAISE NOTICE 'Migration terminée: % assignations créées', migration_count;
END;
$$ LANGUAGE plpgsql;

-- Exécuter la migration
SELECT migrate_jury_assignments_to_rounds();

-- ========================================
-- ÉTAPE 3: Créer la vue pour faciliter les requêtes
-- ========================================

CREATE OR REPLACE VIEW jury_round_assignments_view AS
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

-- ========================================
-- ÉTAPE 4: Vérifications et statistiques
-- ========================================

-- Vérifier les données migrées
SELECT 
    'Assignations migrées' as description,
    COUNT(*) as count
FROM round_jury_assignments
UNION ALL
SELECT 
    'Jurys uniques' as description,
    COUNT(DISTINCT user_id) as count
FROM round_jury_assignments
UNION ALL
SELECT 
    'Rounds avec jurys' as description,
    COUNT(DISTINCT round_id) as count
FROM round_jury_assignments;

-- Afficher un échantillon des données migrées
SELECT 
    rja.id,
    p.full_name as jury_name,
    r.number as round_number,
    r.name as round_name,
    cv.name as version_name,
    rja.created_at
FROM round_jury_assignments rja
JOIN profiles p ON rja.user_id = p.id
JOIN rounds r ON rja.round_id = r.id
JOIN competition_versions cv ON r.version_id = cv.id
ORDER BY cv.name, r.number, p.full_name
LIMIT 10;

-- ========================================
-- ÉTAPE 5: Nettoyage (optionnel)
-- ========================================

-- Nettoyer la fonction de migration
DROP FUNCTION IF EXISTS migrate_jury_assignments_to_rounds();

-- ========================================
-- ÉTAPE 6: Instructions pour l'application
-- ========================================

-- Après avoir exécuté ce script, vous devez:
-- 1. Mettre à jour votre application pour utiliser RoundJuryService
-- 2. Modifier les pages UI pour gérer les jurys par round
-- 3. Tester la nouvelle structure
-- 4. Une fois que tout fonctionne, vous pouvez supprimer l'ancienne table jury_assignments

-- Pour supprimer l'ancienne table (ATTENTION: à faire seulement après avoir testé):
-- DROP TABLE IF EXISTS jury_assignments;

RAISE NOTICE 'Migration vers round_jury_assignments terminée avec succès!';
RAISE NOTICE 'Prochaines étapes:';
RAISE NOTICE '1. Mettre à jour l''application pour utiliser RoundJuryService';
RAISE NOTICE '2. Modifier les pages UI pour gérer les jurys par round';
RAISE NOTICE '3. Tester la nouvelle structure';
RAISE NOTICE '4. Supprimer l''ancienne table jury_assignments si tout fonctionne';
