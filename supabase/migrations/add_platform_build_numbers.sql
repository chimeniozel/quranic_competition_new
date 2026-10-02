-- Mise à jour forcée : un build number par plateforme
--
-- La table ne portait qu'une seule colonne `minimum_version_code`, commune à
-- Android et iOS. Or les deux plateformes ont des numéros de build
-- indépendants : exiger le même nombre des deux côtés bloque forcément l'une
-- ou l'autre à tort.
--
-- Les nouvelles colonnes reprennent la valeur existante pour ne rien changer
-- au comportement actuel tant que l'administrateur ne les modifie pas.
-- L'ancienne colonne est conservée (les versions déjà installées la lisent).

ALTER TABLE app_settings
  ADD COLUMN IF NOT EXISTS minimum_version_code_android INTEGER,
  ADD COLUMN IF NOT EXISTS minimum_version_code_ios INTEGER;

UPDATE app_settings
SET
  minimum_version_code_android = COALESCE(
    minimum_version_code_android,
    minimum_version_code
  ),
  minimum_version_code_ios = COALESCE(
    minimum_version_code_ios,
    minimum_version_code
  );

COMMENT ON COLUMN app_settings.minimum_version_code_android IS
  'Build number minimal exigé sur Android';
COMMENT ON COLUMN app_settings.minimum_version_code_ios IS
  'Build number minimal exigé sur iOS';
COMMENT ON COLUMN app_settings.minimum_version_code IS
  'Obsolète : conservé pour les versions installées qui lisent encore cette colonne';

-- Créer la ligne de configuration si la table est vide
INSERT INTO app_settings (
  minimum_version_code,
  minimum_version_code_android,
  minimum_version_code_ios,
  force_update_enabled,
  update_message
)
SELECT 1, 1, 1, false,
  'يجب تحديث التطبيق إلى أحدث إصدار للاستمرار في الاستخدام.'
WHERE NOT EXISTS (SELECT 1 FROM app_settings);

-- ---------------------------------------------------------------------------
-- Réglage principal : version minimale par plateforme (« 8.3.0 »)
--
-- Les stores publient un numéro de version, jamais un build number : c'est
-- donc la seule valeur que l'application peut lire automatiquement et
-- proposer à l'administrateur en un clic.
-- Laisser vide = on retombe sur la comparaison par build number ci-dessus.
-- ---------------------------------------------------------------------------

ALTER TABLE app_settings
  ADD COLUMN IF NOT EXISTS minimum_version_name_android TEXT,
  ADD COLUMN IF NOT EXISTS minimum_version_name_ios TEXT;

COMMENT ON COLUMN app_settings.minimum_version_name_android IS
  'Version minimale exigée sur Android, ex: 8.3.0 (prioritaire sur le build number)';
COMMENT ON COLUMN app_settings.minimum_version_name_ios IS
  'Version minimale exigée sur iOS, ex: 8.3.0 (prioritaire sur le build number)';
