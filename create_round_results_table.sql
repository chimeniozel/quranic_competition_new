-- Création de la table round_results pour stocker les résultats des rounds
CREATE TABLE round_results (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  participant_id UUID NOT NULL REFERENCES participants(id) ON DELETE CASCADE,
  round_id UUID NOT NULL REFERENCES rounds(id) ON DELETE CASCADE,
  version_id UUID NOT NULL REFERENCES competition_versions(id) ON DELETE CASCADE,
  score DECIMAL(5,2) NOT NULL,
  passed BOOLEAN NOT NULL DEFAULT false,
  age_group TEXT NOT NULL CHECK (age_group IN ('صغار', 'كبار')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index pour améliorer les performances des requêtes
CREATE INDEX idx_round_results_round_id ON round_results(round_id);
CREATE INDEX idx_round_results_version_id ON round_results(version_id);
CREATE INDEX idx_round_results_participant_id ON round_results(participant_id);
CREATE INDEX idx_round_results_round_version ON round_results(round_id, version_id);

-- Index composite pour les requêtes fréquentes
CREATE INDEX idx_round_results_round_version_participant ON round_results(round_id, version_id, participant_id);

-- Contrainte unique pour éviter les doublons
CREATE UNIQUE INDEX idx_round_results_unique ON round_results(participant_id, round_id, version_id);

-- Trigger pour mettre à jour updated_at automatiquement
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_round_results_updated_at 
    BEFORE UPDATE ON round_results 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- Commentaires pour la documentation
COMMENT ON TABLE round_results IS 'Table pour stocker les résultats calculés de chaque participant pour chaque round';
COMMENT ON COLUMN round_results.participant_id IS 'ID du participant';
COMMENT ON COLUMN round_results.round_id IS 'ID du round';
COMMENT ON COLUMN round_results.version_id IS 'ID de la version de la compétition';
COMMENT ON COLUMN round_results.score IS 'Score moyen calculé du participant pour ce round';
COMMENT ON COLUMN round_results.passed IS 'Indique si le participant a réussi ce round';
COMMENT ON COLUMN round_results.age_group IS 'Groupe d''âge du participant (صغار ou كبار)';
COMMENT ON COLUMN round_results.created_at IS 'Date de création de l''enregistrement';
COMMENT ON COLUMN round_results.updated_at IS 'Date de dernière mise à jour de l''enregistrement';
