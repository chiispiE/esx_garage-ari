-- ari_garage SQL migration
-- Run this if upgrading from esx_garage_v2 (or a fresh install)
-- Safe to run multiple times (uses IF NOT EXISTS / checks)

ALTER TABLE `owned_vehicles`
  ADD COLUMN IF NOT EXISTS `parking` VARCHAR(60) NULL AFTER `stored`;

ALTER TABLE `owned_vehicles`
  ADD COLUMN IF NOT EXISTS `pound` VARCHAR(60) NULL AFTER `parking`;

-- Index for faster queries (optional but recommended on large servers)
CREATE INDEX IF NOT EXISTS `idx_ov_owner_parking`
  ON `owned_vehicles` (`owner`, `parking`, `stored`);

CREATE INDEX IF NOT EXISTS `idx_ov_owner_pound`
  ON `owned_vehicles` (`owner`, `pound`, `stored`);
