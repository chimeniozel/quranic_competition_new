-- Ajouter la colonne jury_evaluation_enabled à la table competition_versions
-- Cette colonne contrôle si les jurys ont l'autorisation d'évaluer les participants

ALTER TABLE competition_versions 
ADD COLUMN jury_evaluation_enabled BOOLEAN DEFAULT false;

-- Commentaire pour documentation
COMMENT ON COLUMN competition_versions.jury_evaluation_enabled IS 'Autorisation pour les jurys de commencer l''évaluation des participants (feu vert/rouge)';

