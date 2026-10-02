-- Annonce des fوائد قرآنية : une seule fois, à l'activation
--
-- Une fائدة est créée inactive (is_active = false) : elle n'apparaît pas
-- encore aux participants. La notification partait pourtant dès la création,
-- envoyant tout le monde vers une page où la fائدة n'était pas visible.
--
-- L'annonce part désormais au moment de l'activation. Cette colonne mémorise
-- qu'elle a déjà été envoyée, pour qu'une désactivation suivie d'une
-- réactivation (correction d'une faute de frappe…) ne renotifie pas tous les
-- utilisateurs.

ALTER TABLE quranic_benefits
  ADD COLUMN IF NOT EXISTS notified_at TIMESTAMPTZ;

COMMENT ON COLUMN quranic_benefits.notified_at IS
  'Date d''envoi de l''annonce publique. NULL = jamais annoncée.';

-- Les fوائد déjà actives ont déjà été annoncées à la création : on les marque
-- pour ne pas les ré-annoncer au premier basculement du statut.
UPDATE quranic_benefits
SET notified_at = COALESCE(updated_at, created_at, now())
WHERE is_active AND notified_at IS NULL;
