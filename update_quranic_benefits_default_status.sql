-- Script SQL pour mettre à jour le statut par défaut des nouvelles bénéfices
-- Exécuter ce script si vous avez déjà créé la table avec is_active DEFAULT TRUE

-- 1. Modifier la colonne pour changer le statut par défaut
ALTER TABLE quranic_benefits 
ALTER COLUMN is_active SET DEFAULT FALSE;

-- 2. Optionnel : Mettre à jour les bénéfices existantes qui sont actives
-- (Décommentez cette ligne si vous voulez désactiver toutes les bénéfices existantes)
-- UPDATE quranic_benefits SET is_active = FALSE WHERE is_active = TRUE;

-- 3. Vérifier le changement
SELECT 
    column_name, 
    column_default, 
    data_type 
FROM information_schema.columns 
WHERE table_name = 'quranic_benefits' 
AND column_name = 'is_active';

-- Commentaire : Maintenant, toutes les nouvelles bénéfices seront créées avec is_active = FALSE
-- Les administrateurs devront manuellement activer les bénéfices qu'ils veulent rendre visibles aux participants
