-- ari_garage SQL migration
-- Vehicle state convention used by this resource:
--   0 = out
--   1 = stored in garage
--   2 = impounded

ALTER TABLE `owned_vehicles`
  ADD COLUMN IF NOT EXISTS `parking` VARCHAR(60) NULL DEFAULT NULL AFTER `stored`,
  ADD COLUMN IF NOT EXISTS `pound` VARCHAR(60) NULL DEFAULT NULL AFTER `parking`;

UPDATE `owned_vehicles`
SET
  `parking` = NULLIF(TRIM(`parking`), ''),
  `pound` = NULLIF(TRIM(`pound`), '');

UPDATE `owned_vehicles`
SET `pound` = NULL
WHERE `stored` <> 2;

UPDATE `owned_vehicles`
SET `parking` = NULL
WHERE `stored` <> 1;

CREATE INDEX IF NOT EXISTS `idx_owned_vehicles_owner_stored_parking`
  ON `owned_vehicles` (`owner`, `stored`, `parking`);

CREATE INDEX IF NOT EXISTS `idx_owned_vehicles_owner_stored_pound`
  ON `owned_vehicles` (`owner`, `stored`, `pound`);

CREATE INDEX IF NOT EXISTS `idx_owned_vehicles_owner_plate`
  ON `owned_vehicles` (`owner`, `plate`);
