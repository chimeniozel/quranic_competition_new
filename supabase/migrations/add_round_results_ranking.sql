-- Classement des résultats : rang enregistré et critères de départage
--
-- Avant : seule la note moyenne était enregistrée, et le rang affiché
-- correspondait à la position dans la liste chargée. Un résultat trouvé par
-- la recherche affichait donc un rang faux, et deux notes égales se
-- classaient selon un ordre arbitraire qui pouvait changer d'une requête à
-- l'autre (pagination instable).
--
-- Désormais le rang est calculé une seule fois, au moment du calcul des
-- résultats, selon les critères retenus :
--   1. moyenne générale décroissante
--   2. التجويد décroissant (critère le plus lourd : 70 adultes / 15 enfants)
--   3. حسن الصوت décroissant
--   4. numéro d'inscription croissant
--
-- Le rang affiché, lui, est partagé : deux participants ayant la même
-- moyenne portent le même rang, et les rangs se suivent sans trou
-- (1, 2, 2, 3). Les critères ci-dessus ne servent alors qu'à fixer l'ordre
-- d'affichage.

ALTER TABLE round_results
  ADD COLUMN IF NOT EXISTS rank INTEGER,
  ADD COLUMN IF NOT EXISTS display_order INTEGER,
  ADD COLUMN IF NOT EXISTS tiebreak_tajwid NUMERIC(6, 2),
  ADD COLUMN IF NOT EXISTS tiebreak_voice NUMERIC(6, 2),
  ADD COLUMN IF NOT EXISTS jury_count INTEGER;

COMMENT ON COLUMN round_results.rank IS
  'Rang affiché, par groupe d''âge. Ex aequo : même moyenne = même rang, sans saut (1, 2, 2, 3)';
COMMENT ON COLUMN round_results.display_order IS
  'Ordre d''affichage unique (moyenne, puis التجويد, puis حسن الصوت, puis numéro d''inscription) : garantit une pagination stable';
COMMENT ON COLUMN round_results.tiebreak_tajwid IS
  'Moyenne du critère التجويد, utilisée pour l''ordre d''affichage';
COMMENT ON COLUMN round_results.tiebreak_voice IS
  'Moyenne du critère حسن الصوت, utilisée pour l''ordre d''affichage';
COMMENT ON COLUMN round_results.jury_count IS
  'Nombre d''évaluations retenues dans la moyenne (correcteurs ayant évalué tous les participants)';

-- Un seul résultat par participant et par round : indispensable à l'upsert
-- qui enregistre tout le classement en une fois, et garde-fou contre les
-- doublons de résultats.
CREATE UNIQUE INDEX IF NOT EXISTS round_results_participant_round_uidx
  ON round_results (participant_id, round_id);

-- Lecture paginée du classement d'un groupe d'âge
CREATE INDEX IF NOT EXISTS round_results_round_age_order_idx
  ON round_results (round_id, age_group, display_order);

-- Les résultats déjà calculés n'ont pas de rang : il sera renseigné au
-- prochain calcul. En attendant, l'application retombe sur le tri par note.
