-- Script SQL pour créer un compteur atomique de numéros d'enregistrement
-- Ce script résout le problème de race condition lors des inscriptions simultanées

-- 1. Créer une table pour stocker les compteurs par compétition
CREATE TABLE IF NOT EXISTS competition_counters (
    competition_id UUID PRIMARY KEY REFERENCES competition_versions(id) ON DELETE CASCADE,
    last_registration_number INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. Créer une fonction pour obtenir le prochain numéro d'enregistrement de manière atomique
CREATE OR REPLACE FUNCTION get_next_registration_number(competition_id UUID)
RETURNS INTEGER
LANGUAGE plpgsql
AS $$
DECLARE
    next_number INTEGER;
BEGIN
    -- Utiliser UPSERT (INSERT ... ON CONFLICT) pour une opération atomique
    INSERT INTO competition_counters (competition_id, last_registration_number)
    VALUES (competition_id, 1)
    ON CONFLICT (competition_id) 
    DO UPDATE SET 
        last_registration_number = competition_counters.last_registration_number + 1,
        updated_at = NOW()
    RETURNING last_registration_number INTO next_number;
    
    RETURN next_number;
END;
$$;

-- 3. Créer un trigger pour mettre à jour automatiquement updated_at
CREATE OR REPLACE FUNCTION update_competition_counters_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;

CREATE TRIGGER update_competition_counters_updated_at
    BEFORE UPDATE ON competition_counters
    FOR EACH ROW
    EXECUTE FUNCTION update_competition_counters_updated_at();

-- 4. Initialiser les compteurs pour les compétitions existantes
INSERT INTO competition_counters (competition_id, last_registration_number)
SELECT 
    cv.id as competition_id,
    COALESCE(MAX(p.registration_number), 0) as last_registration_number
FROM competition_versions cv
LEFT JOIN participants p ON p.competition_id = cv.id
GROUP BY cv.id
ON CONFLICT (competition_id) DO NOTHING;

-- 5. Créer un index pour améliorer les performances
CREATE INDEX IF NOT EXISTS idx_competition_counters_competition_id 
ON competition_counters(competition_id);

-- 6. Ajouter une contrainte pour s'assurer que les numéros sont positifs
ALTER TABLE competition_counters 
ADD CONSTRAINT check_positive_registration_number 
CHECK (last_registration_number >= 0);

-- 7. Créer une fonction de nettoyage pour supprimer les compteurs des compétitions supprimées
CREATE OR REPLACE FUNCTION cleanup_competition_counters()
RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
    -- Supprimer les compteurs des compétitions qui n'existent plus
    DELETE FROM competition_counters 
    WHERE competition_id NOT IN (
        SELECT id FROM competition_versions
    );
END;
$$;

-- 8. Commentaires pour la documentation
COMMENT ON TABLE competition_counters IS 'Compteurs atomiques pour les numéros d''enregistrement par compétition';
COMMENT ON FUNCTION get_next_registration_number(UUID) IS 'Fonction atomique pour obtenir le prochain numéro d''enregistrement d''une compétition';
COMMENT ON FUNCTION cleanup_competition_counters() IS 'Fonction de nettoyage pour supprimer les compteurs orphelins';

-- 9. Exemple d'utilisation (commenté)
/*
-- Tester la fonction
SELECT get_next_registration_number('your-competition-id-here');

-- Voir les compteurs actuels
SELECT 
    cc.competition_id,
    cv.name as competition_name,
    cc.last_registration_number,
    cc.updated_at
FROM competition_counters cc
JOIN competition_versions cv ON cv.id = cc.competition_id
ORDER BY cc.updated_at DESC;
*/
