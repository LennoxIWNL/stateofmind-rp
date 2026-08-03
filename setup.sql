-- ===========================================================================
--  State of Mind RP  --  setup.sql
--
--  THE single database import. Create an empty database, import this file,
--  point `set mysql_connection_string` at it, and the server has everything
--  it needs.
--
--    mysql -u root -p -e "CREATE DATABASE stateofmindrp CHARACTER SET utf8mb4"
--    mysql -u root -p stateofmindrp < setup.sql
--
--  Safe to re-run. Every statement is IF NOT EXISTS, INSERT IGNORE, or a
--  guarded ALTER, so importing over a live database adds what is missing and
--  changes nothing else.
--
--  This file is the source of truth. When a som-* resource needs a table it
--  is added HERE, not to a per-resource sql/ folder, because two copies of a
--  schema drift and the one you import is never the one you edited.
--
--  Section order matters: foreign keys reference tables defined above them.
--
--    1. Identity            som_users, som_characters
--    2. Money               balances, ledger, bank accounts
--    3. Business and jobs   register, applications, treasury
--    4. Gangs and turf
--    5. Vehicles and licences
--    6. Economy             market, fines, department funding
--    7. Phone               bills, saved accounts, settings
--   7b. Police              custody, impounds, flagged plates
--    8. Preserved third party   ps-mdt, ox_doorlock
--    9. Seed data
-- ===========================================================================

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- ===========================================================================
--  1. IDENTITY
-- ===========================================================================

-- One row per real person, keyed by Rockstar license.
CREATE TABLE IF NOT EXISTS `som_users` (
  `license`     VARCHAR(64)  NOT NULL,
  `discord`     VARCHAR(64)  DEFAULT NULL,
  `fivem`       VARCHAR(64)  DEFAULT NULL,
  `steam`       VARCHAR(64)  DEFAULT NULL,
  `last_ip`     VARCHAR(45)  DEFAULT NULL,
  `last_name`   VARCHAR(64)  DEFAULT NULL,
  `first_seen`  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `last_seen`   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `playtime`    INT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (`license`),
  KEY `idx_discord` (`discord`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- One row per character. citizenid is the identifier every other table joins on.
CREATE TABLE IF NOT EXISTS `som_characters` (
  `citizenid`   VARCHAR(16)  NOT NULL,
  `license`     VARCHAR(64)  NOT NULL,
  -- Nullable on purpose: deleting a character sets slot to NULL to free it.
  -- MySQL allows repeated NULLs in a unique index, so a slot can be reused
  -- any number of times without the audit history being hard deleted.
  `slot`        TINYINT UNSIGNED DEFAULT NULL,
  `firstname`   VARCHAR(32)  NOT NULL,
  `lastname`    VARCHAR(32)  NOT NULL,
  `dob`         DATE         NOT NULL,
  `gender`      TINYINT UNSIGNED NOT NULL DEFAULT 0,
  `nationality` VARCHAR(32)  NOT NULL DEFAULT 'Unknown',
  `phone`       VARCHAR(16)  DEFAULT NULL,
  `job`         VARCHAR(32)  NOT NULL DEFAULT 'unemployed',
  `job_grade`   TINYINT UNSIGNED NOT NULL DEFAULT 0,
  `job_duty`    TINYINT(1)   NOT NULL DEFAULT 0,
  `gang`        VARCHAR(32)  NOT NULL DEFAULT 'none',
  `gang_grade`  TINYINT UNSIGNED NOT NULL DEFAULT 0,
  `position`    JSON         DEFAULT NULL,
  `metadata`    JSON         DEFAULT NULL,
  `appearance`  JSON         DEFAULT NULL,
  -- Shown on the ID card. Null renders a silhouette. NUI cannot read the
  -- game's ped headshot texture, so this has to be a URL something else fills
  -- in rather than anything the client can produce on its own.
  `photo`       VARCHAR(255) DEFAULT NULL,
  -- Owned and written by ox_inventory, not by som-core. Its som bridge points
  -- {user_table} at this table and {user_column} at citizenid, so the column
  -- has to exist here or every player load fails.
  `inventory`   LONGTEXT     DEFAULT NULL,
  `created_at`  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `last_played` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted`     TINYINT(1)   NOT NULL DEFAULT 0,
  PRIMARY KEY (`citizenid`),
  UNIQUE KEY `uniq_license_slot` (`license`, `slot`),
  KEY `idx_license` (`license`),
  KEY `idx_name` (`lastname`, `firstname`),
  KEY `idx_phone` (`phone`),
  CONSTRAINT `fk_char_user` FOREIGN KEY (`license`) REFERENCES `som_users` (`license`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ===========================================================================
--  2. MONEY
--
--  Balances are only ever written by som-core/server/money.lua. No job or
--  gameplay script touches them directly, and every movement writes a ledger
--  row in the same transaction.
-- ===========================================================================

CREATE TABLE IF NOT EXISTS `som_character_money` (
  `citizenid` VARCHAR(16) NOT NULL,
  `cash`      BIGINT NOT NULL DEFAULT 0,
  `bank`      BIGINT NOT NULL DEFAULT 0,
  `crypto`    BIGINT NOT NULL DEFAULT 0,
  `dirty`     BIGINT NOT NULL DEFAULT 0,
  PRIMARY KEY (`citizenid`),
  CONSTRAINT `fk_money_char` FOREIGN KEY (`citizenid`) REFERENCES `som_characters` (`citizenid`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- The audit ledger. One row per money movement, no exceptions.
-- Sink/faucet analysis and anti-dupe investigation both query this.
-- `resource` is filled from GetInvokingResource() so every entry is attributable.
CREATE TABLE IF NOT EXISTS `som_transactions` (
  `id`          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `citizenid`   VARCHAR(16)  DEFAULT NULL,
  `account`     VARCHAR(16)  NOT NULL,
  `amount`      BIGINT       NOT NULL,
  `balance`     BIGINT       NOT NULL,
  `direction`   ENUM('credit','debit') NOT NULL,
  `flow`        ENUM('faucet','sink','transfer') NOT NULL,
  `reason`      VARCHAR(64)  NOT NULL,
  `resource`    VARCHAR(64)  NOT NULL,
  `counterparty` VARCHAR(32) DEFAULT NULL,
  `business_id` INT UNSIGNED DEFAULT NULL,
  `created_at`  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_citizen_time` (`citizenid`, `created_at`),
  KEY `idx_flow_time` (`flow`, `created_at`),
  KEY `idx_reason` (`reason`),
  KEY `idx_resource` (`resource`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Personal, business, gang and offshore accounts share one table.
--
-- Personal account numbers are plain 8 digit values with no branded prefix:
-- players read them aloud, print them on adverts and save them as contacts,
-- and a "SOM-" in front reads as a script artefact. Business rows keep a
-- GOV-/BUS- key because those are internal and never shown to a player.
CREATE TABLE IF NOT EXISTS `som_bank_accounts` (
  `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `account_no` VARCHAR(24)  NOT NULL,
  `label`      VARCHAR(64)  NOT NULL,
  `type`       ENUM('personal','business','gang','offshore') NOT NULL DEFAULT 'personal',
  `owner`      VARCHAR(16)  DEFAULT NULL,
  `balance`    BIGINT       NOT NULL DEFAULT 0,
  `frozen`     TINYINT(1)   NOT NULL DEFAULT 0,
  `created_at` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_account_no` (`account_no`),
  KEY `idx_owner` (`owner`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Who may touch a shared account, and how much they may pull per day.
CREATE TABLE IF NOT EXISTS `som_bank_access` (
  `account_id`   INT UNSIGNED NOT NULL,
  `citizenid`    VARCHAR(16)  NOT NULL,
  `can_deposit`  TINYINT(1)   NOT NULL DEFAULT 1,
  `can_withdraw` TINYINT(1)   NOT NULL DEFAULT 0,
  `daily_limit`  BIGINT       NOT NULL DEFAULT 0,
  PRIMARY KEY (`account_id`, `citizenid`),
  CONSTRAINT `fk_access_account` FOREIGN KEY (`account_id`) REFERENCES `som_bank_accounts` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ===========================================================================
--  3. BUSINESS AND JOBS
--
--  Job definitions are config (som-core/shared/jobs.lua). These tables hold
--  runtime state only.
-- ===========================================================================

-- `funding` is the difference between a shop and a government department:
--   sales     revenue comes from what it sells
--   fines     revenue comes from penalties, never from the officer issuing them
--   treasury  funded by the city budget, sells nothing
CREATE TABLE IF NOT EXISTS `som_businesses` (
  `id`           INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `name`         VARCHAR(48)  NOT NULL,
  `label`        VARCHAR(64)  NOT NULL,
  `job`          VARCHAR(32)  DEFAULT NULL,
  `owner`        VARCHAR(16)  DEFAULT NULL,
  `account_id`   INT UNSIGNED DEFAULT NULL,
  `tax_rate`     DECIMAL(5,4) NOT NULL DEFAULT 0.0000,
  `is_front`     TINYINT(1)   NOT NULL DEFAULT 0,
  `launder_cut`  DECIMAL(5,4) NOT NULL DEFAULT 0.0000,
  `revenue_total` BIGINT      NOT NULL DEFAULT 0,
  `upkeep`       BIGINT       NOT NULL DEFAULT 0,
  `funding`      ENUM('sales','fines','treasury') NOT NULL DEFAULT 'sales',
  `category`     ENUM('private','government','emergency') NOT NULL DEFAULT 'private',
  -- Departments that exist but are not yet in use stay inactive, so BCSO and
  -- SASP can be switched on later without a migration.
  `active`       TINYINT(1)   NOT NULL DEFAULT 1,
  `treasury_cut` DECIMAL(5,4) NOT NULL DEFAULT 0.0000,
  `created_at`   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_name` (`name`),
  KEY `idx_job` (`job`),
  CONSTRAINT `fk_business_account` FOREIGN KEY (`account_id`) REFERENCES `som_bank_accounts` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Upgrade path for databases created before the columns above existed.
-- MariaDB has no ADD COLUMN IF NOT EXISTS, hence the procedure.
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

CALL som_add_column('som_businesses', 'funding',
    "ENUM('sales','fines','treasury') NOT NULL DEFAULT 'sales'");
CALL som_add_column('som_businesses', 'category',
    "ENUM('private','government','emergency') NOT NULL DEFAULT 'private'");
CALL som_add_column('som_businesses', 'active', 'TINYINT(1) NOT NULL DEFAULT 1');
CALL som_add_column('som_businesses', 'treasury_cut', 'DECIMAL(5,4) NOT NULL DEFAULT 0.0000');

-- som_add_column stays defined until section 8b, where the rest of the
-- upgrade ALTERs run. It is dropped there.

-- Applying happens at an NPC, not through a /job command. This is that queue.
CREATE TABLE IF NOT EXISTS `som_job_applications` (
  `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `citizenid`  VARCHAR(16)  NOT NULL,
  `job`        VARCHAR(32)  NOT NULL,
  `status`     ENUM('pending','approved','rejected') NOT NULL DEFAULT 'pending',
  `note`       VARCHAR(255) DEFAULT NULL,
  `reviewed_by` VARCHAR(16) DEFAULT NULL,
  `created_at` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_open_application` (`citizenid`, `job`, `status`),
  KEY `idx_job_status` (`job`, `status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- The city treasury, visible to players. Taxes flow in, department budgets out.
CREATE TABLE IF NOT EXISTS `som_treasury` (
  `id`       TINYINT UNSIGNED NOT NULL DEFAULT 1,
  `balance`  BIGINT NOT NULL DEFAULT 0,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ===========================================================================
--  4. GANGS AND TURF
-- ===========================================================================

CREATE TABLE IF NOT EXISTS `som_gangs` (
  `name`       VARCHAR(32)  NOT NULL,
  `label`      VARCHAR(64)  NOT NULL,
  `account_id` INT UNSIGNED DEFAULT NULL,
  `stash_id`   VARCHAR(48)  DEFAULT NULL,
  `color`      VARCHAR(9)   NOT NULL DEFAULT '#ff1493',
  `created_at` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`name`),
  CONSTRAINT `fk_gang_account` FOREIGN KEY (`account_id`) REFERENCES `som_bank_accounts` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `som_gang_grades` (
  `gang`   VARCHAR(32) NOT NULL,
  `grade`  TINYINT UNSIGNED NOT NULL,
  `label`  VARCHAR(48) NOT NULL,
  `is_boss` TINYINT(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (`gang`, `grade`),
  CONSTRAINT `fk_grade_gang` FOREIGN KEY (`gang`) REFERENCES `som_gangs` (`name`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `som_turf` (
  `id`            INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `name`          VARCHAR(48)  NOT NULL,
  `label`         VARCHAR(64)  NOT NULL,
  `owner_gang`    VARCHAR(32)  DEFAULT NULL,
  `control_points` INT         NOT NULL DEFAULT 0,
  `contested_by`  VARCHAR(32)  DEFAULT NULL,
  `contest_started` TIMESTAMP  NULL DEFAULT NULL,
  `claimed_at`    TIMESTAMP    NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_turf_name` (`name`),
  KEY `idx_owner` (`owner_gang`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Append-only log of control point changes, so turf swings are auditable and a
-- HUD can show recent activity without polling live state.
CREATE TABLE IF NOT EXISTS `som_turf_events` (
  `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `turf_id`    INT UNSIGNED NOT NULL,
  `gang`       VARCHAR(32)  NOT NULL,
  `citizenid`  VARCHAR(16)  DEFAULT NULL,
  `points`     INT          NOT NULL,
  `action`     VARCHAR(32)  NOT NULL,
  `created_at` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_turf_time` (`turf_id`, `created_at`),
  CONSTRAINT `fk_event_turf` FOREIGN KEY (`turf_id`) REFERENCES `som_turf` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ===========================================================================
--  5. VEHICLES AND LICENCES
-- ===========================================================================

CREATE TABLE IF NOT EXISTS `som_vehicles` (
  `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `citizenid`  VARCHAR(16)  NOT NULL,
  `plate`      VARCHAR(12)  NOT NULL,
  `model`      VARCHAR(32)  NOT NULL,
  `props`      JSON         DEFAULT NULL,
  `garage`     VARCHAR(48)  NOT NULL DEFAULT 'impound',
  `state`      ENUM('out','garaged','impounded') NOT NULL DEFAULT 'garaged',
  `fuel`       TINYINT UNSIGNED NOT NULL DEFAULT 100,
  `body`       DECIMAL(6,2) NOT NULL DEFAULT 1000.00,
  `engine`     DECIMAL(6,2) NOT NULL DEFAULT 1000.00,
  `created_at` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_plate` (`plate`),
  KEY `idx_owner` (`citizenid`),
  CONSTRAINT `fk_veh_char` FOREIGN KEY (`citizenid`) REFERENCES `som_characters` (`citizenid`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `som_licenses` (
  `citizenid`  VARCHAR(16) NOT NULL,
  `type`       VARCHAR(32) NOT NULL,
  `issued_by`  VARCHAR(16) DEFAULT NULL,
  `issued_at`  TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `revoked`    TINYINT(1)  NOT NULL DEFAULT 0,
  PRIMARY KEY (`citizenid`, `type`),
  CONSTRAINT `fk_lic_char` FOREIGN KEY (`citizenid`) REFERENCES `som_characters` (`citizenid`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ===========================================================================
--  6. ECONOMY
-- ===========================================================================

-- One row per tradable item. current_price moves down as volume is dumped and
-- recovers over time toward base_price, so flooding a market is self limiting
-- and walking away from it is rewarded.
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

-- A fine credits the issuing DEPARTMENT, never the officer. Officers earn a
-- salary; if writing tickets paid them personally the incentive would be to
-- fine as much as possible, which is the opposite of what policing should
-- reward.
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

-- ===========================================================================
--  7. PHONE
--
--  Deliberately small. There is no separate account model: the bank app reads
--  som_transactions and som_bank_accounts directly, which is the whole reason
--  for building the phone rather than adopting one that brings its own schema.
-- ===========================================================================

-- A bill is a REQUEST, never a withdrawal. Money moves only when the recipient
-- accepts, so a leaked account number can never drain anyone.
CREATE TABLE IF NOT EXISTS `som_phone_bills` (
  `id`          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `from_citizenid` VARCHAR(16) NOT NULL,
  `to_citizenid`   VARCHAR(16) NOT NULL,
  -- Recorded so the bill still shows who sent it when the sender is offline,
  -- and so a renamed character cannot rewrite history.
  `from_name`   VARCHAR(72)  NOT NULL,
  `account_no`  VARCHAR(24)  DEFAULT NULL,
  `business`    VARCHAR(48)  DEFAULT NULL,
  `amount`      BIGINT       NOT NULL,
  `reason`      VARCHAR(128) NOT NULL,
  `status`      ENUM('pending','paid','declined','cancelled') NOT NULL DEFAULT 'pending',
  -- Auto collection. A police fine is not an offer, so ignoring your phone
  -- cannot be a way to dodge one: som-phone sweeps overdue rows and settles
  -- them. Player-to-player bills leave auto_collect at 0 and stay pending
  -- until accepted or declined, however long that takes.
  `auto_collect` TINYINT(1)  NOT NULL DEFAULT 0,
  `due_at`      DATETIME     NULL DEFAULT NULL,
  `created_at`  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `settled_at`  TIMESTAMP    NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_to_status` (`to_citizenid`, `status`),
  KEY `idx_from` (`from_citizenid`),
  KEY `idx_due` (`status`, `auto_collect`, `due_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- What a player keeps after somebody shares their number with them.
CREATE TABLE IF NOT EXISTS `som_phone_accounts` (
  `citizenid`  VARCHAR(16) NOT NULL,
  `account_no` VARCHAR(24) NOT NULL,
  `label`      VARCHAR(72) NOT NULL,
  `saved_at`   TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`citizenid`, `account_no`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Theme and wallpaper are supporter perks, so what is stored here is validated
-- server side against the player's entitlements rather than trusted.
CREATE TABLE IF NOT EXISTS `som_phone_settings` (
  `citizenid`  VARCHAR(16) NOT NULL,
  `theme`      VARCHAR(32) NOT NULL DEFAULT 'default',
  `wallpaper`  VARCHAR(64) NOT NULL DEFAULT 'default',
  `updated_at` TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------------
-- Appearance changes
--
-- Every alteration to a character's FACE, with who and when. The appearance
-- itself lives in som_characters.appearance; this is the audit trail.
--
-- It exists because a barber can change a face, which has to be possible so a
-- character creator mistake is recoverable, but a face that can change
-- silently is a face that cannot be investigated. Nothing reads this yet;
-- som-police and the MDT will.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS `som_appearance_log` (
  `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `citizenid`  VARCHAR(16) NOT NULL,
  `scope`      VARCHAR(24) NOT NULL,
  `section`    VARCHAR(24) NOT NULL,
  `price`      BIGINT NOT NULL DEFAULT 0,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_citizen_time` (`citizenid`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ===========================================================================
--  7b. POLICE
--
--  Custody, impounds and flagged plates. Certifications are NOT here: they are
--  rows in som_licenses with a `cert.` prefix on the type, which already
--  carries issued_by, issued_at and revoked, so every grant is attributable
--  without another table.
--
--  Like som_appearance_log above, these carry no foreign keys and index
--  instead. They are audit trails, and a record that cascades away when a
--  character is deleted is not one. That is the deliberate trade: the rows
--  outlive the characters they name, so a citizenid here may no longer resolve.
-- ===========================================================================

-- Every cuffing, and its release. The chain the custody verbs write to, and
-- what jail will read.
--
-- Cuffing is NOT police-only: it needs handcuffs and proximity, nothing else,
-- so a kidnapping writes rows here exactly as an arrest does. `by_job` is what
-- separates the two after the fact, recorded at the time because the person's
-- job can change afterwards and the record should not.
CREATE TABLE IF NOT EXISTS `som_police_custody` (
  `id`          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `citizenid`   VARCHAR(16) NOT NULL,
  `by_cid`      VARCHAR(16) DEFAULT NULL,
  `by_job`      VARCHAR(32) DEFAULT NULL,
  `by_grade`    TINYINT UNSIGNED DEFAULT NULL,
  `cuffed_at`   TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `released_at` TIMESTAMP   NULL DEFAULT NULL,
  `released_by` VARCHAR(16) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_citizen_time` (`citizenid`, `cuffed_at`),
  -- Finds the open detention for a person: released_at IS NULL.
  KEY `idx_open` (`citizenid`, `released_at`),
  KEY `idx_by` (`by_cid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Impound records. The LIVE state of a vehicle is som_vehicles.state, which
-- already has an 'impounded' value; this is the history behind it, including
-- who seized it and what the owner was charged to get it back.
CREATE TABLE IF NOT EXISTS `som_police_impound` (
  `id`           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `plate`        VARCHAR(12) NOT NULL,
  `citizenid`    VARCHAR(16) DEFAULT NULL,
  `officer_cid`  VARCHAR(16) DEFAULT NULL,
  `reason`       VARCHAR(160) NOT NULL DEFAULT '',
  `fee`          BIGINT NOT NULL DEFAULT 0,
  `impounded_at` TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `released_at`  TIMESTAMP   NULL DEFAULT NULL,
  `released_to`  VARCHAR(16) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_plate` (`plate`),
  KEY `idx_open` (`plate`, `released_at`),
  KEY `idx_owner` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Flagged plates.
--
-- Rows are kept and cleared rather than deleted, so "this plate was flagged for
-- a month last year" survives the flag being lifted. A plate is currently
-- flagged if it has a row with cleared_at IS NULL.
CREATE TABLE IF NOT EXISTS `som_police_plates` (
  `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `plate`      VARCHAR(12) NOT NULL,
  `reason`     VARCHAR(160) NOT NULL DEFAULT '',
  `flagged_by` VARCHAR(16) DEFAULT NULL,
  `flagged_at` TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `cleared_at` TIMESTAMP   NULL DEFAULT NULL,
  `cleared_by` VARCHAR(16) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_plate_active` (`plate`, `cleared_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ===========================================================================
--  8. PRESERVED THIRD PARTY
--
--  Not SOM code. These resources are kept as-is, so their schema is reproduced
--  here verbatim to keep the import to a single file. If either is upgraded,
--  re-check its own SQL against this section.
-- ===========================================================================

-- --- ps-mdt ---------------------------------------------------------------

CREATE TABLE IF NOT EXISTS `mdt_data` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `cid` VARCHAR(20) DEFAULT NULL,
  `information` MEDIUMTEXT DEFAULT NULL,
  `tags` TEXT NOT NULL,
  `gallery` TEXT NOT NULL,
  `jobtype` VARCHAR(25) DEFAULT 'police',
  `pfp` TEXT DEFAULT NULL,
  `fingerprint` VARCHAR(50) DEFAULT NULL,
  PRIMARY KEY (`cid`),
  KEY `id` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `mdt_bulletin` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `title` TEXT NOT NULL,
  `desc` TEXT NOT NULL,
  `author` varchar(50) NOT NULL,
  `time` varchar(20) NOT NULL,
  `jobtype` VARCHAR(25) DEFAULT 'police',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `mdt_reports` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `author` varchar(50) DEFAULT NULL,
  `title` varchar(255) DEFAULT NULL,
  `type` varchar(50) DEFAULT NULL,
  `details` text DEFAULT NULL,
  `tags` text DEFAULT NULL,
  `officersinvolved` text DEFAULT NULL,
  `civsinvolved` text DEFAULT NULL,
  `gallery` text DEFAULT NULL,
  `time` varchar(20) DEFAULT NULL,
  `jobtype` varchar(25) DEFAULT 'police',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `mdt_bolos` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `author` varchar(50) DEFAULT NULL,
  `title` varchar(50) DEFAULT NULL,
  `plate` varchar(50) DEFAULT NULL,
  `owner` varchar(50) DEFAULT NULL,
  `individual` varchar(50) DEFAULT NULL,
  `detail` text DEFAULT NULL,
  `tags` text DEFAULT NULL,
  `gallery` text DEFAULT NULL,
  `officersinvolved` text DEFAULT NULL,
  `time` varchar(20) DEFAULT NULL,
  `jobtype` varchar(25) NOT NULL DEFAULT 'police',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `mdt_convictions` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `cid` varchar(50) DEFAULT NULL,
  `linkedincident` int(11) NOT NULL DEFAULT 0,
  `warrant` varchar(50) DEFAULT NULL,
  `guilty` varchar(50) DEFAULT NULL,
  `processed` varchar(50) DEFAULT NULL,
  `associated` varchar(50) DEFAULT '0',
  `charges` text DEFAULT NULL,
  `fine` int(11) DEFAULT 0,
  `sentence` int(11) DEFAULT 0,
  `recfine` int(11) DEFAULT 0,
  `recsentence` int(11) DEFAULT 0,
  `time` varchar(20) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `mdt_incidents` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `author` varchar(50) NOT NULL DEFAULT '',
  `title` varchar(50) NOT NULL DEFAULT '0',
  `details` text NOT NULL,
  `tags` text NOT NULL,
  `officersinvolved` text NOT NULL,
  `civsinvolved` text NOT NULL,
  `evidence` text NOT NULL,
  `time` varchar(20) DEFAULT NULL,
  `jobtype` varchar(25) NOT NULL DEFAULT 'police',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `mdt_logs` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `text` text NOT NULL,
  `time` varchar(20) DEFAULT NULL,
  `jobtype` varchar(25) DEFAULT 'police',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `mdt_vehicleinfo` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `plate` varchar(50) DEFAULT NULL,
  `information` text NOT NULL DEFAULT '',
  `stolen` tinyint(1) NOT NULL DEFAULT 0,
  `code5` tinyint(1) NOT NULL DEFAULT 0,
  `image` text NOT NULL DEFAULT '',
  `points` int(11) DEFAULT 0,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `mdt_weaponinfo` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `serial` varchar(50) DEFAULT NULL,
  `owner` varchar(50) DEFAULT NULL,
  `information` text NOT NULL DEFAULT '',
  `weapClass` varchar(50) DEFAULT NULL,
  `weapModel` varchar(50) DEFAULT NULL,
  `image` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `serial` (`serial`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `mdt_impound` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `vehicleid` int(11) NOT NULL,
  `linkedreport` int(11) NOT NULL,
  `fee` int(11) DEFAULT NULL,
  `time` varchar(255) NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `mdt_clocking` (
  `id` int(10) NOT NULL AUTO_INCREMENT,
  `user_id` varchar(50) NOT NULL DEFAULT '',
  `firstname` varchar(255) NOT NULL DEFAULT '',
  `lastname` varchar(255) NOT NULL DEFAULT '',
  `clock_in_time` varchar(255) NOT NULL DEFAULT '',
  `clock_out_time` varchar(50) DEFAULT NULL,
  `total_time` int(10) NOT NULL DEFAULT '0',
  PRIMARY KEY (`user_id`) USING BTREE,
  KEY `id` (`id`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --- ox_doorlock ----------------------------------------------------------

CREATE TABLE IF NOT EXISTS `ox_doorlock` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(50) NOT NULL,
  `data` longtext NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ===========================================================================
--  8b. UPGRADES
--
--  Columns added after the tables above first shipped. Fresh installs already
--  have them from the CREATE statements; these exist so importing over a live
--  database catches up without a separate migration file.
-- ===========================================================================

CALL som_add_column('som_characters', 'photo', 'VARCHAR(255) DEFAULT NULL');
CALL som_add_column('som_phone_bills', 'auto_collect', 'TINYINT(1) NOT NULL DEFAULT 0');
CALL som_add_column('som_phone_bills', 'due_at', 'DATETIME NULL DEFAULT NULL');

DROP PROCEDURE IF EXISTS som_add_column;

-- ===========================================================================
--  9. SEED DATA
--
--  Opening balances are PLACEHOLDER FLOAT, not a balance decision. Businesses
--  are meant to earn from player activity and be taxed into som_treasury; the
--  numbers below only exist so payroll has something to debit on day one.
--  See AUDIT.md section 12.2.
-- ===========================================================================

INSERT IGNORE INTO `som_treasury` (`id`, `balance`) VALUES (1, 0);

-- Government and emergency departments. LSPD is the only force active at
-- launch; BCSO and SASP exist so they can be switched on by flipping `active`
-- when the population justifies them, with no migration.
INSERT IGNORE INTO `som_bank_accounts` (`account_no`, `label`, `type`, `balance`) VALUES
  ('GOV-LSPD',  'Los Santos Police Department',   'business', 750000),
  ('GOV-BCSO',  'Blaine County Sheriff Office',   'business', 0),
  ('GOV-SASP',  'San Andreas State Police',       'business', 0),
  ('GOV-EMS',   'San Andreas Medical Services',   'business', 500000),
  ('BUS-LSC',   'Los Santos Customs',             'business', 150000),
  ('BUS-CAB',   'Downtown Cab Co.',               'business', 100000),
  ('BUS-POSTOP','Post OP',                        'business', 100000);

INSERT IGNORE INTO `som_businesses`
  (`name`, `label`, `job`, `account_id`, `tax_rate`, `funding`, `category`, `active`, `treasury_cut`)
VALUES
  ('lspd',        'Los Santos Police Department', 'police',    (SELECT id FROM som_bank_accounts WHERE account_no='GOV-LSPD'),   0.0000, 'fines',    'government', 1, 0.0000),
  ('bcso',        'Blaine County Sheriff Office', NULL,        (SELECT id FROM som_bank_accounts WHERE account_no='GOV-BCSO'),   0.0000, 'fines',    'government', 0, 0.0000),
  ('sasp',        'San Andreas State Police',     NULL,        (SELECT id FROM som_bank_accounts WHERE account_no='GOV-SASP'),   0.0000, 'fines',    'government', 0, 0.0000),
  -- EMS is funded by the city, not by what it sells. Charging for medical care
  -- would make treatment a paywall.
  ('ems',         'San Andreas Medical Services', 'ambulance', (SELECT id FROM som_bank_accounts WHERE account_no='GOV-EMS'),    0.0000, 'treasury', 'emergency',  1, 0.0000),
  ('lscustoms',   'Los Santos Customs',           'mechanic',  (SELECT id FROM som_bank_accounts WHERE account_no='BUS-LSC'),    0.0000, 'sales',    'private',    1, 0.0800),
  ('downtowncab', 'Downtown Cab Co.',             'taxi',      (SELECT id FROM som_bank_accounts WHERE account_no='BUS-CAB'),    0.0000, 'sales',    'private',    1, 0.0800),
  ('postop',      'Post OP',                      'delivery',  (SELECT id FROM som_bank_accounts WHERE account_no='BUS-POSTOP'), 0.0000, 'sales',    'private',    1, 0.0800);

-- Corrections for databases seeded before the funding model existed, where
-- INSERT IGNORE above skipped the rows and left them on column defaults.
UPDATE `som_businesses`
   SET `funding` = 'fines', `category` = 'government', `active` = 1,
       `account_id` = (SELECT id FROM som_bank_accounts WHERE account_no = 'GOV-LSPD')
 WHERE `name` = 'lspd';

UPDATE `som_businesses` SET `funding` = 'treasury', `category` = 'emergency' WHERE `name` = 'ems';

UPDATE `som_businesses` SET `funding` = 'sales', `category` = 'private', `treasury_cut` = 0.0800
 WHERE `name` IN ('lscustoms', 'downtowncab', 'postop');

-- Superseded by the ems department above.
DELETE FROM `som_businesses` WHERE `name` = 'pillbox';
DELETE FROM `som_bank_accounts` WHERE `account_no` IN ('BUS-LSPD', 'BUS-PILLBOX');

-- Gangs listed in som-core/shared/gangs.lua. Turf rows are Phase 6.
INSERT IGNORE INTO `som_gangs` (`name`, `label`, `color`) VALUES
  ('none',    'No Gang',      '#666666'),
  ('lostmc',  'The Lost MC',  '#8b1a1a'),
  ('ballas',  'Ballas',       '#6b3fa0'),
  ('vagos',   'Vagos',        '#d4a017'),
  ('families','Families',     '#2e8b57'),
  ('cartel',  'Cartel',       '#b8860b');

SET FOREIGN_KEY_CHECKS = 1;
