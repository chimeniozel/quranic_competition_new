-- Création des tables pour le système de quiz

-- Table des niveaux de quiz
CREATE TABLE IF NOT EXISTS quiz_levels (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT NOT NULL,
    "order" INTEGER NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Table des questions de quiz
CREATE TABLE IF NOT EXISTS quiz_questions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    level_id UUID NOT NULL REFERENCES quiz_levels(id) ON DELETE CASCADE,
    question TEXT NOT NULL,
    image_url TEXT,
    points INTEGER NOT NULL DEFAULT 1,
    "order" INTEGER NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Table des options de réponses
CREATE TABLE IF NOT EXISTS quiz_options (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    question_id UUID NOT NULL REFERENCES quiz_questions(id) ON DELETE CASCADE,
    text TEXT NOT NULL,
    is_correct BOOLEAN NOT NULL DEFAULT FALSE,
    "order" INTEGER NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Note: Les résultats de quiz sont calculés en temps réel et ne sont pas sauvegardés

-- Index pour améliorer les performances
CREATE INDEX IF NOT EXISTS idx_quiz_levels_order ON quiz_levels("order");
CREATE INDEX IF NOT EXISTS idx_quiz_levels_active ON quiz_levels(is_active);
CREATE INDEX IF NOT EXISTS idx_quiz_questions_level ON quiz_questions(level_id);
CREATE INDEX IF NOT EXISTS idx_quiz_questions_order ON quiz_questions("order");
CREATE INDEX IF NOT EXISTS idx_quiz_questions_active ON quiz_questions(is_active);
CREATE INDEX IF NOT EXISTS idx_quiz_options_question ON quiz_options(question_id);
CREATE INDEX IF NOT EXISTS idx_quiz_options_order ON quiz_options("order");

-- Fonction pour mettre à jour automatiquement updated_at
CREATE OR REPLACE FUNCTION update_quiz_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers pour mettre à jour automatiquement updated_at
CREATE TRIGGER trigger_update_quiz_levels_updated_at
    BEFORE UPDATE ON quiz_levels
    FOR EACH ROW
    EXECUTE FUNCTION update_quiz_updated_at();

CREATE TRIGGER trigger_update_quiz_questions_updated_at
    BEFORE UPDATE ON quiz_questions
    FOR EACH ROW
    EXECUTE FUNCTION update_quiz_updated_at();

-- RLS (Row Level Security)
ALTER TABLE quiz_levels ENABLE ROW LEVEL SECURITY;
ALTER TABLE quiz_questions ENABLE ROW LEVEL SECURITY;
ALTER TABLE quiz_options ENABLE ROW LEVEL SECURITY;

-- Politiques pour quiz_levels
CREATE POLICY "Allow read access to active levels for authenticated users"
    ON quiz_levels FOR SELECT
    TO authenticated
    USING (is_active = true);

CREATE POLICY "Allow full access to levels for admins"
    ON quiz_levels FOR ALL
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM app_users 
            WHERE app_users.id = auth.uid() 
            AND app_users.role IN ('admin', 'super_admin')
        )
    );

-- Politiques pour quiz_questions
CREATE POLICY "Allow read access to active questions for authenticated users"
    ON quiz_questions FOR SELECT
    TO authenticated
    USING (is_active = true);

CREATE POLICY "Allow full access to questions for admins"
    ON quiz_questions FOR ALL
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM app_users 
            WHERE app_users.id = auth.uid() 
            AND app_users.role IN ('admin', 'super_admin')
        )
    );

-- Politiques pour quiz_options
CREATE POLICY "Allow read access to options for authenticated users"
    ON quiz_options FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "Allow full access to options for admins"
    ON quiz_options FOR ALL
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM app_users 
            WHERE app_users.id = auth.uid() 
            AND app_users.role IN ('admin', 'super_admin')
        )
    );

-- Note: Aucune politique RLS nécessaire pour les résultats car ils ne sont pas sauvegardés

-- Commentaires sur les tables
COMMENT ON TABLE quiz_levels IS 'Niveaux de difficulté des quiz';
COMMENT ON TABLE quiz_questions IS 'Questions des quiz organisées par niveau';
COMMENT ON TABLE quiz_options IS 'Options de réponses pour chaque question';

-- Commentaires sur les colonnes importantes
COMMENT ON COLUMN quiz_levels."order" IS 'Ordre d''affichage des niveaux';
COMMENT ON COLUMN quiz_questions.points IS 'Points attribués pour une bonne réponse';
COMMENT ON COLUMN quiz_options.is_correct IS 'Indique si cette option est la bonne réponse';

-- Insérer quelques exemples de niveaux (optionnel)
-- INSERT INTO quiz_levels (name, description, "order") VALUES
-- ('مبتدئ', 'مستوى للمبتدئين في التجويد', 1),
-- ('متوسط', 'مستوى متوسط في التجويد', 2),
-- ('متقدم', 'مستوى متقدم في التجويد', 3);
