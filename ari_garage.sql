-- =============================================================================
-- ari_garage — Migración owned_vehicles (ESX Legacy / oxmysql)
-- Compatible con MySQL 5.7+ y MariaDB 10.4+ (sin depender de ADD COLUMN IF NOT EXISTS)
--
-- Convención `stored` usada por el recurso:
--   0 = en la calle
--   1 = guardado en garaje
--   2 = en depósito (impound)
-- La columna `stored` en ESX suele ser TINYINT(1); los valores 0–2 son válidos.
-- =============================================================================

-- Columna parking
SET @db := DATABASE();
SET @exists := (
  SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = @db AND TABLE_NAME = 'owned_vehicles' AND COLUMN_NAME = 'parking'
);
SET @sql := IF(@exists = 0,
  'ALTER TABLE `owned_vehicles` ADD COLUMN `parking` VARCHAR(60) NULL DEFAULT NULL AFTER `stored`',
  'SELECT 1'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- Columna pound
SET @exists := (
  SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = @db AND TABLE_NAME = 'owned_vehicles' AND COLUMN_NAME = 'pound'
);
SET @sql := IF(@exists = 0,
  'ALTER TABLE `owned_vehicles` ADD COLUMN `pound` VARCHAR(60) NULL DEFAULT NULL AFTER `parking`',
  'SELECT 1'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- Normalizar cadenas vacías
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

-- Índices (omitir si ya existen; en caso de error "Duplicate key name", ignorar)
SET @idx := (
  SELECT COUNT(*) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = @db AND TABLE_NAME = 'owned_vehicles' AND INDEX_NAME = 'idx_owned_vehicles_owner_stored_parking'
);
SET @sql := IF(@idx = 0,
  'CREATE INDEX `idx_owned_vehicles_owner_stored_parking` ON `owned_vehicles` (`owner`, `stored`, `parking`)',
  'SELECT 1'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx := (
  SELECT COUNT(*) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = @db AND TABLE_NAME = 'owned_vehicles' AND INDEX_NAME = 'idx_owned_vehicles_owner_stored_pound'
);
SET @sql := IF(@idx = 0,
  'CREATE INDEX `idx_owned_vehicles_owner_stored_pound` ON `owned_vehicles` (`owner`, `stored`, `pound`)',
  'SELECT 1'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx := (
  SELECT COUNT(*) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = @db AND TABLE_NAME = 'owned_vehicles' AND INDEX_NAME = 'idx_owned_vehicles_owner_plate'
);
SET @sql := IF(@idx = 0,
  'CREATE INDEX `idx_owned_vehicles_owner_plate` ON `owned_vehicles` (`owner`, `plate`)',
  'SELECT 1'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
