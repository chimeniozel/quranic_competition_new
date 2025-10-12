-- Script pour ajouter la colonne rejection_reason à la table participants
-- Exécuter ce script dans Supabase SQL Editor

-- Ajouter la colonne rejection_reason
ALTER TABLE participants 
ADD COLUMN rejection_reason TEXT;

-- Ajouter un commentaire pour documenter la colonne
COMMENT ON COLUMN participants.rejection_reason IS 'سبب رفض المشارك إذا كان مرفوضاً';

-- Optionnel: Ajouter des raisons de refus par défaut pour les participants existants qui sont refusés
-- (Décommentez les lignes suivantes si vous voulez mettre à jour les données existantes)

-- UPDATE participants 
-- SET rejection_reason = 'تم رفض المشارك بناءً على المعايير المحددة'
-- WHERE is_accepted = false;

-- Vérifier que la colonne a été ajoutée
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'participants' 
AND column_name = 'rejection_reason';
