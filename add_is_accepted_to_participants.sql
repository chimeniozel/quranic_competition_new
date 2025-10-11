-- Ajouter le champ is_accepted à la table participants
ALTER TABLE participants 
ADD COLUMN IF NOT EXISTS is_accepted BOOLEAN DEFAULT true;

-- Créer un index pour améliorer les performances des requêtes
CREATE INDEX IF NOT EXISTS idx_participants_is_accepted ON participants(is_accepted);

-- Commentaire pour le champ
COMMENT ON COLUMN participants.is_accepted IS 'Indique si la participation du candidat est acceptée (true) ou annulée (false)';

