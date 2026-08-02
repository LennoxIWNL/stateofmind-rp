-- SOM economy, Phase 4.
--
-- Additive migration. Safe to re-run: every statement is IF NOT EXISTS or
-- INSERT IGNORE, and the ALTERs are guarded by a procedure because MariaDB
-- has no ADD COLUMN IF NOT EXISTS.
--
-- Apply after som_schema.sql.

-- ---------------------------------------------------------------------------
-- Business register extensions
-- ---------------------------------------------------------------------------

DROP PROCEDURE IF EXISTS som_add_column;
DELIMITER //
CREATE PROCEDURE som_add_column(
    IN tbl VARCHAR(64), IN col VARCHAR(64), IN def TEXT
)
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = tbl AND COLUMN_NAME = col
    ) THEN
        SET @s = CONCAT('ALTER TABLE `', tbl, '` ADD COLUMN `', col, '` ', def);
        PREPARE stmt FROM @s; EXECUTE stmt; DEALLOCATE PREPARE stmt;
    END IF;
END //
DELIMITER ;

-- How a business is funded. This is the difference between a shop and a
-- government department:
--   sales     revenue comes from what it sells
--   fines     revenue comes from penalties, never from the officer issuing them
--   treasury  funded by the city budget, sells nothing
CALL som_add_column('som_businesses', 'funding',
    "ENUM('sales','fines','treasury') NOT NULL DEFAULT 'sales'");

CALL som_add_column('som_businesses', 'category',
    "ENUM('private','government','emergency') NOT NULL DEFAULT 'private'");

-- Departments that exist but are not yet in use stay inactive, so BCSO and
-- SASP can be switched on later without a migration.
CALL som_add_column('som_businesses', 'active', 'TINYINT(1) NOT NULL DEFAULT 1');

-- Share of this business's revenue taken as tax into the treasury.
CALL som_add_column('som_businesses', 'treasury_cut', 'DECIMAL(5,4) NOT NULL DEFAULT 0.0000');

DROP PROCEDURE IF EXISTS som_add_column;

-- ---------------------------------------------------------------------------
-- Market
--
-- One row per tradable item. current_price moves down as volume is dumped and
-- recovers over time toward base_price, so flooding a market is self limiting
-- and walking away from it is rewarded.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS `som_market` (
  `item`          VARCHAR(48) NOT NULL,
  `label`         VARCHAR(64) NOT NULL,
  `category`      VARCHAR(32) NOT NULL DEFAULT 'general',
  `base_price`    INT UNSIGNED NOT NULL,
  `current_price` INT UNSIGNED NOT NULL,
  `min_price`     INT UNSIGNED NOT NULL,
  `max_price`     INT UNSIGNED NOT NULL,
  -- Fraction the price drops per unit sold, and the fraction of the gap back
  -- to base recovered per hour.
  `saturation`    DECIMAL(6,5) NOT NULL DEFAULT 0.00300,
  `recovery`      DECIMAL(6,5) NOT NULL DEFAULT 0.05000,
  `volume_sold`   BIGINT NOT NULL DEFAULT 0,
  `updated_at`    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`item`),
  KEY `idx_category` (`category`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Append-only record of every sale, so price movement can be explained after
-- the fact and abuse can be traced to a citizen.
CREATE TABLE IF NOT EXISTS `som_market_sales` (
  `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `item`       VARCHAR(48) NOT NULL,
  `citizenid`  VARCHAR(16) DEFAULT NULL,
  `quantity`   INT UNSIGNED NOT NULL,
  `unit_price` INT UNSIGNED NOT NULL,
  `gross`      BIGINT NOT NULL,
  `business`   VARCHAR(48) DEFAULT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_item_time` (`item`, `created_at`),
  KEY `idx_citizen` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------------
-- Fines
--
-- A fine credits the issuing DEPARTMENT, never the officer. Officers earn a
-- salary; if writing tickets paid them personally the incentive would be to
-- fine as much as possible, which is the opposite of what policing should
-- reward.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS `som_fines` (
  `id`          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `citizenid`   VARCHAR(16) NOT NULL,
  `issued_by`   VARCHAR(16) NOT NULL,
  `department`  VARCHAR(48) NOT NULL,
  `reason`      VARCHAR(128) NOT NULL,
  `amount`      BIGINT NOT NULL,
  `status`      ENUM('unpaid','paid','void') NOT NULL DEFAULT 'unpaid',
  `voided_by`   VARCHAR(16) DEFAULT NULL,
  `created_at`  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `paid_at`     TIMESTAMP NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_citizen_status` (`citizenid`, `status`),
  KEY `idx_issuer` (`issued_by`),
  KEY `idx_department` (`department`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------------
-- Government departments
--
-- LSPD is the only one active at launch. BCSO and SASP exist so they can be
-- switched on by flipping `active` when the population justifies them.
-- ---------------------------------------------------------------------------

INSERT IGNORE INTO `som_bank_accounts` (`account_no`, `label`, `type`, `balance`) VALUES
  ('GOV-LSPD',  'Los Santos Police Department',   'business', 750000),
  ('GOV-BCSO',  'Blaine County Sheriff Office',   'business', 0),
  ('GOV-SASP',  'San Andreas State Police',       'business', 0),
  ('GOV-EMS',   'San Andreas Medical Services',   'business', 500000);

INSERT IGNORE INTO `som_businesses`
  (`name`, `label`, `job`, `account_id`, `tax_rate`, `funding`, `category`, `active`)
VALUES
  ('lspd', 'Los Santos Police Department', 'police', (SELECT id FROM som_bank_accounts WHERE account_no='GOV-LSPD'), 0.0000, 'fines',    'government', 1),
  ('bcso', 'Blaine County Sheriff Office', NULL,     (SELECT id FROM som_bank_accounts WHERE account_no='GOV-BCSO'), 0.0000, 'fines',    'government', 0),
  ('sasp', 'San Andreas State Police',     NULL,     (SELECT id FROM som_bank_accounts WHERE account_no='GOV-SASP'), 0.0000, 'fines',    'government', 0),
  ('ems',  'San Andreas Medical Services', 'ambulance', (SELECT id FROM som_bank_accounts WHERE account_no='GOV-EMS'), 0.0000, 'treasury', 'emergency', 1);

-- lspd already exists from som_schema.sql, so the INSERT IGNORE above skips it
-- and it keeps the column defaults. Correct it explicitly, and point it at the
-- government account rather than the original placeholder.
UPDATE `som_businesses`
   SET `funding` = 'fines',
       `category` = 'government',
       `active` = 1,
       `account_id` = (SELECT id FROM som_bank_accounts WHERE account_no = 'GOV-LSPD')
 WHERE `name` = 'lspd';

-- EMS is funded by the city, not by what it sells. Charging for medical care
-- would make treatment a paywall, so its account is topped up from the
-- treasury instead.
UPDATE `som_businesses` SET `funding` = 'treasury', `category` = 'emergency' WHERE `name` = 'ems';

-- Existing private businesses keep selling, and start paying tax.
UPDATE `som_businesses` SET `funding` = 'sales', `category` = 'private', `treasury_cut` = 0.0800
  WHERE `name` IN ('lscustoms', 'downtowncab', 'postop');

-- The old placeholder pillbox row is superseded by the ems department above.
DELETE FROM `som_businesses` WHERE `name` = 'pillbox';
