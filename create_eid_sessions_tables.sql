-- Table pour les sessions Eid (une seule session active à la fois)
CREATE TABLE IF NOT EXISTS eid_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT,
  start_date TIMESTAMP WITH TIME ZONE,
  end_date TIMESTAMP WITH TIME ZONE,
  is_active BOOLEAN NOT NULL DEFAULT false, -- Si la session est visible sur la page d'accueil
  is_open BOOLEAN NOT NULL DEFAULT true, -- Si l'inscription est ouverte
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Contrainte pour s'assurer qu'une seule session active à la fois
-- Nous utilisons un trigger ou une fonction pour gérer cela au niveau applicatif
-- car EXCLUDE nécessite une extension (btree_gist) qui n'est pas toujours disponible

-- Table pour les participants aux sessions Eid
CREATE TABLE IF NOT EXISTS eid_participants (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID NOT NULL REFERENCES eid_sessions(id) ON DELETE CASCADE,
  full_name TEXT NOT NULL,
  phone TEXT NOT NULL,
  gender TEXT NOT NULL CHECK (gender IN ('ذكر', 'أنثى')),
  is_winner BOOLEAN NOT NULL DEFAULT false, -- Si le participant a été sélectionné par la loterie
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  UNIQUE(session_id, phone) -- Un participant ne peut s'inscrire qu'une fois par session avec le même numéro de téléphone
);

-- Index pour améliorer les performances
CREATE INDEX IF NOT EXISTS idx_eid_sessions_is_active ON eid_sessions(is_active);
CREATE INDEX IF NOT EXISTS idx_eid_sessions_is_open ON eid_sessions(is_open);
CREATE INDEX IF NOT EXISTS idx_eid_participants_session_id ON eid_participants(session_id);
CREATE INDEX IF NOT EXISTS idx_eid_participants_is_winner ON eid_participants(is_winner);
CREATE INDEX IF NOT EXISTS idx_eid_participants_session_winner ON eid_participants(session_id, is_winner);

-- Fonction pour mettre à jour automatiquement updated_at
CREATE OR REPLACE FUNCTION update_eid_sessions_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger pour mettre à jour updated_at automatiquement
CREATE TRIGGER update_eid_sessions_updated_at_trigger
  BEFORE UPDATE ON eid_sessions
  FOR EACH ROW
  EXECUTE FUNCTION update_eid_sessions_updated_at();

-- Commentaires pour la documentation
COMMENT ON TABLE eid_sessions IS 'Table pour gérer les sessions de pause de l''Aïd / Nouvelle session';
COMMENT ON COLUMN eid_sessions.is_active IS 'Si la session est visible sur la page d''accueil des participants';
COMMENT ON COLUMN eid_sessions.is_open IS 'Si l''inscription est ouverte pour les participants';
COMMENT ON TABLE eid_participants IS 'Table pour stocker les participants aux sessions Eid';
COMMENT ON COLUMN eid_participants.is_winner IS 'Si le participant a été sélectionné par la loterie';

