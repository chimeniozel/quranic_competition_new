-- Table pour gérer les paramètres de mise à jour forcée de l'application
CREATE TABLE IF NOT EXISTS app_settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  minimum_version_code INTEGER NOT NULL DEFAULT 1,
  force_update_enabled BOOLEAN NOT NULL DEFAULT false,
  update_message TEXT DEFAULT 'يجب تحديث التطبيق إلى أحدث إصدار للاستمرار في الاستخدام.',
  update_url_android TEXT DEFAULT 'https://play.google.com/store/apps/details?id=com.chemeni.quranic_competition',
  update_url_ios TEXT DEFAULT 'https://apps.apple.com/app/id6739760516',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Insérer une ligne par défaut
INSERT INTO app_settings (minimum_version_code, force_update_enabled, update_message)
VALUES (8, false, 'يجب تحديث التطبيق إلى أحدث إصدار للاستمرار في الاستخدام.')
ON CONFLICT DO NOTHING;

-- Fonction pour mettre à jour updated_at automatiquement
CREATE OR REPLACE FUNCTION update_app_settings_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger pour mettre à jour updated_at
CREATE TRIGGER update_app_settings_updated_at_trigger
BEFORE UPDATE ON app_settings
FOR EACH ROW
EXECUTE FUNCTION update_app_settings_updated_at();

-- Commentaires
COMMENT ON TABLE app_settings IS 'Paramètres de mise à jour forcée de l''application';
COMMENT ON COLUMN app_settings.minimum_version_code IS 'Version minimale requise (version code)';
COMMENT ON COLUMN app_settings.force_update_enabled IS 'Activer/désactiver la mise à jour forcée';
COMMENT ON COLUMN app_settings.update_message IS 'Message affiché à l''utilisateur';
COMMENT ON COLUMN app_settings.update_url_android IS 'URL Google Play Store';
COMMENT ON COLUMN app_settings.update_url_ios IS 'URL App Store';

