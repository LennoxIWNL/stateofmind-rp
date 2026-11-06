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
--   8c. Compatibility views    players, player_vehicles, for ps-mdt's qb SQL
--    9. Seed data
--
--  Doors are NOT here. sql/mrpd-doors.sql is a separate one-time import,
--  because ox_doorlock has no unique key on `name` and re-running this file
--  would insert a duplicate set of doors every time.
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

-- Same problem for indexes: MariaDB accepts CREATE INDEX IF NOT EXISTS but
-- MySQL 8 does not, so neither is portable on its own.
DROP PROCEDURE IF EXISTS som_add_index;
DELIMITER //
CREATE PROCEDURE som_add_index(
    IN tbl VARCHAR(64), IN idx VARCHAR(64), IN cols TEXT
)
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.STATISTICS
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = tbl AND INDEX_NAME = idx
    ) THEN
        SET @s = CONCAT('CREATE INDEX `', idx, '` ON `', tbl, '` (', cols, ')');
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

-- som_add_column and som_add_index stay defined until section 8b, where the
-- rest of the upgrade ALTERs run. Both are dropped there.

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

-- One row shape serves three kinds of vehicle, distinguished by who owns it:
--
--   personal      citizenid set, owner_group NULL
--   org fleet     citizenid NULL, owner_group set (a department pool car)
--   job-locked    BOTH set, group_restricted = 1 (an officer's bought cruiser:
--                 genuinely theirs, but it only leaves the PD garage)
--
-- `citizenid` is therefore NULLABLE. A pool car belongs to the department, not
-- to a person, and forcing a citizenid on it would mean inventing an owner.
-- The foreign key still holds for rows that do name one: SQL foreign keys
-- permit NULL.
--
-- `state` is the liveness flag and doubles as pool availability: a taken car is
-- 'out', so it disappears from everyone else's list with no second table.
CREATE TABLE IF NOT EXISTS `som_vehicles` (
  `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `citizenid`  VARCHAR(16)  DEFAULT NULL,
  `plate`      VARCHAR(12)  NOT NULL,
  `model`      VARCHAR(32)  NOT NULL,
  `props`      JSON         DEFAULT NULL,
  `garage`     VARCHAR(48)  NOT NULL DEFAULT 'impound',
  `state`      ENUM('out','garaged','impounded') NOT NULL DEFAULT 'garaged',
  `fuel`       TINYINT UNSIGNED NOT NULL DEFAULT 100,
  `body`       DECIMAL(6,2) NOT NULL DEFAULT 1000.00,
  `engine`     DECIMAL(6,2) NOT NULL DEFAULT 1000.00,
  -- Business or gang that owns it, by som_businesses.name / som_gangs.name.
  `owner_group`      VARCHAR(48) DEFAULT NULL,
  -- Only retrievable at that group's garage, even by its personal owner.
  `group_restricted` TINYINT(1)  NOT NULL DEFAULT 0,
  -- Who currently has a pool car out, and since when. Accountability, and what
  -- a supervisory force-return would read.
  `assigned_to` VARCHAR(16) DEFAULT NULL,
  `taken_at`    TIMESTAMP   NULL DEFAULT NULL,
  -- What was paid for it. The partial refund on leaving a job is a share of
  -- this, so it has to survive the price in config changing afterwards.
  `purchase_price` BIGINT NOT NULL DEFAULT 0,
  `created_at` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_plate` (`plate`),
  KEY `idx_owner` (`citizenid`),
  KEY `idx_group` (`owner_group`, `state`),
  KEY `idx_garage` (`garage`, `state`),
  CONSTRAINT `fk_veh_char` FOREIGN KEY (`citizenid`) REFERENCES `som_characters` (`citizenid`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `som_licenses` (
  `citizenid`  VARCHAR(16) NOT NULL,
  `type`       VARCHAR(32) NOT NULL,
  `issued_by`  VARCHAR(16) DEFAULT NULL,
  `issued_at`  TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `revoked`    TINYINT(1)  NOT NULL DEFAULT 0,
  `suspended_until` TIMESTAMP NULL DEFAULT NULL,
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

-- One row per phone ITEM, keyed by the imei the server writes into the item's
-- metadata. The passcode is a salted SHA-256 with a pepper from a convar; the
-- hash is never sent to the page.
CREATE TABLE IF NOT EXISTS `som_phone_devices` (
  `imei`       CHAR(16) NOT NULL,
  `pass_hash`  CHAR(64) DEFAULT NULL,
  `pass_salt`  CHAR(12) DEFAULT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`imei`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Every action that changes something, and whether it worked. Reads are not
-- recorded. The pipeline writes this; nothing else does.
CREATE TABLE IF NOT EXISTS `som_phone_audit` (
  `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `citizenid`  VARCHAR(16) NOT NULL,
  `app`        VARCHAR(32) NOT NULL,
  `action`     VARCHAR(32) NOT NULL,
  `ok`         TINYINT(1) NOT NULL DEFAULT 1,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_citizen` (`citizenid`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `som_phone_contacts` (
  `citizenid` VARCHAR(16) NOT NULL,
  `number`    VARCHAR(16) NOT NULL,
  `name`      VARCHAR(32) NOT NULL,
  PRIMARY KEY (`citizenid`, `number`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `som_phone_blocks` (
  `citizenid` VARCHAR(16) NOT NULL,
  `number`    VARCHAR(16) NOT NULL,
  PRIMARY KEY (`citizenid`, `number`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Keyed by phone NUMBER, not citizen, so a message still reaches a character
-- whose phone item was lost and replaced.
CREATE TABLE IF NOT EXISTS `som_phone_messages` (
  `id`          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `from_number` VARCHAR(16) NOT NULL,
  `to_number`   VARCHAR(16) NOT NULL,
  `body`        VARCHAR(280) NOT NULL,
  `created_at`  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `read_at`     TIMESTAMP NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_to` (`to_number`, `from_number`),
  KEY `idx_from` (`from_number`, `to_number`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `som_phone_calls` (
  `id`          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `from_number` VARCHAR(16) NOT NULL,
  `to_number`   VARCHAR(16) NOT NULL,
  `status`      ENUM('answered','missed','declined','unavailable') NOT NULL,
  `answered`    TINYINT(1) NOT NULL DEFAULT 0,
  `created_at`  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_from` (`from_number`),
  KEY `idx_to` (`to_number`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- One handle per character. `handle` is unique, so two characters can never
-- hold the same one whatever order they race in.
CREATE TABLE IF NOT EXISTS `som_phone_handles` (
  `citizenid`  VARCHAR(16) NOT NULL,
  `handle`     VARCHAR(16) NOT NULL,
  `colour`     VARCHAR(7)  DEFAULT NULL,
  `changed_at` TIMESTAMP NULL DEFAULT NULL,
  PRIMARY KEY (`citizenid`),
  UNIQUE KEY `uniq_handle` (`handle`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `som_phone_posts` (
  `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `citizenid`  VARCHAR(16) NOT NULL,
  `business`   VARCHAR(64) DEFAULT NULL,
  `body`       VARCHAR(280) NOT NULL,
  `image`      VARCHAR(255) DEFAULT NULL,
  `reply_to`   BIGINT UNSIGNED DEFAULT NULL,
  `likes`      INT UNSIGNED NOT NULL DEFAULT 0,
  `removed`    TINYINT(1) NOT NULL DEFAULT 0,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_feed` (`removed`, `reply_to`, `id`),
  KEY `idx_reply` (`reply_to`),
  KEY `idx_author` (`citizenid`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `som_phone_likes` (
  `post_id`   BIGINT UNSIGNED NOT NULL,
  `citizenid` VARCHAR(16) NOT NULL,
  PRIMARY KEY (`post_id`, `citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `som_phone_reports` (
  `post_id`    BIGINT UNSIGNED NOT NULL,
  `citizenid`  VARCHAR(16) NOT NULL,
  `reason`     VARCHAR(120) NOT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`post_id`, `citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `som_phone_adverts` (
  `id`          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `citizenid`   VARCHAR(16) NOT NULL,
  `category`    VARCHAR(16) NOT NULL,
  `title`       VARCHAR(48) NOT NULL,
  `body`        VARCHAR(280) NOT NULL,
  `price`       VARCHAR(24) DEFAULT NULL,
  `show_number` TINYINT(1) NOT NULL DEFAULT 0,
  `business`    VARCHAR(64) DEFAULT NULL,
  `status`      ENUM('active','removed') NOT NULL DEFAULT 'active',
  `created_at`  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `expires_at`  DATETIME NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_active` (`status`, `expires_at`),
  KEY `idx_owner` (`citizenid`, `status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- White pages: a character is findable by name only if they opted in.
CREATE TABLE IF NOT EXISTS `som_phone_pages_optin` (
  `citizenid` VARCHAR(16) NOT NULL,
  `listed`    TINYINT(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `som_phone_notes` (
  `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `citizenid`  VARCHAR(16) NOT NULL,
  `title`      VARCHAR(40) NOT NULL,
  `body`       VARCHAR(2000) NOT NULL DEFAULT '',
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_owner` (`citizenid`, `updated_at`)
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

-- Per-person roles on an MDT incident.
--
-- ps-mdt stores the people on an incident as two JSON blobs of DISPLAY STRINGS
-- (`officersinvolved`, `civsinvolved`). There is no citizen id in them and no
-- per-person field, so victim versus suspect versus witness cannot be
-- expressed, and the person's identity is lost the moment they become a tag.
-- This is the junction table that fixes it.
--
-- `incident_id` refers to `mdt_incidents(id)` with NO foreign key, on purpose
-- and for two reasons: nothing else in ps-mdt's schema carries one, and that
-- table belongs to a preserved third-party resource that may be dropped and
-- recreated by its own SQL on upgrade. A constraint pointing into it would turn
-- their migration into our outage. Rows are therefore cleaned by the delete
-- path in som-police rather than by a cascade.
--
-- `role` is an ENUM rather than a VARCHAR so an unknown role is refused by the
-- database as well as by the server. The server validates against the same list
-- before it ever reaches here; this is the second lock, not the first.
--
-- UNIQUE on (incident_id, citizenid) makes assignment an upsert: one person
-- holds one role per incident, and setting it again moves it rather than
-- stacking a second row.
CREATE TABLE IF NOT EXISTS `som_incident_people` (
  `id`          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `incident_id` INT UNSIGNED NOT NULL,
  `citizenid`   VARCHAR(16) NOT NULL,
  `role`        ENUM('victim','suspect','witness','complainant','reporting') NOT NULL DEFAULT 'witness',
  `added_by`    VARCHAR(16) DEFAULT NULL,
  `created`     TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_incident_person` (`incident_id`, `citizenid`),
  KEY `idx_incident` (`incident_id`),
  KEY `idx_citizen` (`citizenid`)
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
--  7d. HOUSING (som-housing)
--
--  A property is a DOOR IN THE WORLD plus a SHELL MODEL, never a mapped
--  interior. One shell serves every property that uses it, because each
--  occupied property gets its own routing bucket, so `shell` here is a model
--  name and not a location.
--
--  NOTE ON NAMES. `player_houses`, `houselocations` and `apartments` already
--  exist further down as empty compatibility VIEWS for ps-mdt. They are views,
--  not tables, and a real table cannot take those names. Everything here is
--  som_ prefixed for that reason as much as for consistency.
-- ===========================================================================

-- The property itself. Rows are SEEDED FROM CONFIG at boot and reconciled the
-- way som-garage reconciles its fleet: config decides what exists, the row
-- carries what has happened to it since.
--
-- `realtor_only` is the expensive tier. It cannot be bought outright at all,
-- which is what makes a real estate agent a job rather than a convenience.
CREATE TABLE IF NOT EXISTS `som_properties` (
  `id`            INT UNSIGNED NOT NULL AUTO_INCREMENT,
  -- The config key, not a display name. Stable across restarts, which is what
  -- makes reconciliation possible at all.
  `slug`          VARCHAR(64)  NOT NULL,
  `label`         VARCHAR(96)  NOT NULL,
  `type`          ENUM('house','apartment','warehouse') NOT NULL DEFAULT 'house',
  `tier`          VARCHAR(24)  NOT NULL DEFAULT 'standard',
  -- A model name from qb-interior or jordqn_free_shells. The exit offset that
  -- goes with it lives in som-housing/shared/shells.lua, not here: an offset is
  -- a property of the MODEL, so storing it per row would be the same number
  -- copied a hundred times and wrong the moment a shell is swapped.
  `shell`         VARCHAR(64)  NOT NULL,
  `door_x`        DOUBLE       NOT NULL,
  `door_y`        DOUBLE       NOT NULL,
  `door_z`        DOUBLE       NOT NULL,
  `door_heading`  FLOAT        NOT NULL DEFAULT 0.0,
  `price`         BIGINT       NOT NULL DEFAULT 0,
  `stash_slots`   INT          NOT NULL DEFAULT 50,
  `stash_weight`  INT          NOT NULL DEFAULT 100000,
  `for_sale`      TINYINT(1)   NOT NULL DEFAULT 1,
  `realtor_only`  TINYINT(1)   NOT NULL DEFAULT 0,
  `created_at`    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_slug` (`slug`),
  KEY `idx_sale` (`for_sale`, `type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Who may open a property, and in what capacity.
--
-- A ROW RATHER THAN A METADATA BLOB, deliberately. som-core's setMetadata
-- whitelists keys against Config.DefaultMetadata and silently returns false for
-- anything else, so a keyring stored there would fail without erroring. A row
-- is also what lets a key be revoked by whoever granted it.
CREATE TABLE IF NOT EXISTS `som_property_owners` (
  `property_id` INT UNSIGNED NOT NULL,
  `citizenid`   VARCHAR(16)  NOT NULL,
  -- owner    bought it, and the only role finance is ever written against
  -- co_owner holds a key, cannot sell
  -- tenant   holds a key while rent is paid
  `role`        ENUM('owner','co_owner','tenant') NOT NULL DEFAULT 'owner',
  `granted_by`  VARCHAR(16)  DEFAULT NULL,
  `granted_at`  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`property_id`, `citizenid`),
  KEY `idx_citizen` (`citizenid`),
  CONSTRAINT `fk_owner_property` FOREIGN KEY (`property_id`)
    REFERENCES `som_properties` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Placed furniture.
--
-- OFFSETS ARE RELATIVE TO THE SHELL ORIGIN, never world coordinates. The shell
-- is spawned somewhere different for every bucket, so a world coordinate would
-- be correct exactly once. Relative offsets make one row set work in every
-- instance of that property.
CREATE TABLE IF NOT EXISTS `som_property_furniture` (
  `id`          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `property_id` INT UNSIGNED NOT NULL,
  `model`       VARCHAR(64)  NOT NULL,
  `off_x`       FLOAT NOT NULL,
  `off_y`       FLOAT NOT NULL,
  `off_z`       FLOAT NOT NULL,
  `rot_x`       FLOAT NOT NULL DEFAULT 0.0,
  `rot_y`       FLOAT NOT NULL DEFAULT 0.0,
  `rot_z`       FLOAT NOT NULL DEFAULT 0.0,
  `placed_by`   VARCHAR(16)  DEFAULT NULL,
  `placed_at`   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_property` (`property_id`),
  CONSTRAINT `fk_furniture_property` FOREIGN KEY (`property_id`)
    REFERENCES `som_properties` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- A mortgage.
--
-- THE DEBT LIVES HERE AND NOWHERE ELSE. It is deliberately not a balance column
-- on som_properties: AUDIT 8.5 records storing a balance on the asset row as the
-- mistake made against som-banking, because two places then disagree about what
-- is owed and neither is obviously wrong.
--
-- Each instalment becomes a real som_phone_bills row with auto_collect set, so
-- the phone's existing sweep does the collecting and this table only tracks the
-- contract. `missed_cycles` is what that sweep increments when the debtor is
-- offline, because som-phone's collector resolves debtors from memory and would
-- otherwise skip them silently and forever.
CREATE TABLE IF NOT EXISTS `som_property_finance` (
  `id`            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `property_id`   INT UNSIGNED NOT NULL,
  `citizenid`     VARCHAR(16)  NOT NULL,
  `principal`     BIGINT       NOT NULL,
  `remaining`     BIGINT       NOT NULL,
  `instalment`    BIGINT       NOT NULL,
  `interval_days` INT          NOT NULL DEFAULT 7,
  `next_due`      DATETIME     NOT NULL,
  `missed_cycles` INT          NOT NULL DEFAULT 0,
  -- The realtor who wrote the contract. A mortgage requires one to be online,
  -- and this is who the commission is owed to.
  `realtor_citizenid` VARCHAR(16) DEFAULT NULL,
  `status`        ENUM('active','settled','repossessed') NOT NULL DEFAULT 'active',
  `created_at`    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_citizen_status` (`citizenid`, `status`),
  KEY `idx_due` (`status`, `next_due`),
  CONSTRAINT `fk_finance_property` FOREIGN KEY (`property_id`)
    REFERENCES `som_properties` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- A search warrant against a PROPERTY.
--
-- ps-mdt's own warrants are person-based, a flag on mdt_convictions keyed by
-- cid, so there is nothing there to extend and this is separate on purpose.
--
-- A WARRANT IS AUTHORITY, NOT A KEY. Nothing in this table unlocks a door. It
-- records that a raid was lawful, which is what makes an unwarranted breach a
-- decision with a consequence rather than something the game simply refuses.
CREATE TABLE IF NOT EXISTS `som_property_warrants` (
  `id`           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `property_id`  INT UNSIGNED NOT NULL,
  `requested_by` VARCHAR(16)  NOT NULL,
  `approved_by`  VARCHAR(16)  DEFAULT NULL,
  `reason`       VARCHAR(255) NOT NULL,
  `granted_at`   TIMESTAMP    NULL DEFAULT NULL,
  `expires_at`   DATETIME     NULL DEFAULT NULL,
  `served_at`    TIMESTAMP    NULL DEFAULT NULL,
  `status`       ENUM('requested','granted','refused','served','expired')
                 NOT NULL DEFAULT 'requested',
  `created_at`   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_property_status` (`property_id`, `status`),
  KEY `idx_expiry` (`status`, `expires_at`),
  CONSTRAINT `fk_warrant_property` FOREIGN KEY (`property_id`)
    REFERENCES `som_properties` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Raids, warranted or not. Written whether or not a warrant existed, because
-- the record of an unlawful entry is the entire point of recording them.
CREATE TABLE IF NOT EXISTS `som_property_raids` (
  `id`          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `property_id` INT UNSIGNED NOT NULL,
  `officer`     VARCHAR(16)  NOT NULL,
  `warrant_id`  BIGINT UNSIGNED DEFAULT NULL,
  `method`      ENUM('ram','lockpick','key') NOT NULL,
  `lawful`      TINYINT(1)   NOT NULL DEFAULT 0,
  `raided_at`   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_property` (`property_id`),
  KEY `idx_officer` (`officer`),
  CONSTRAINT `fk_raid_property` FOREIGN KEY (`property_id`)
    REFERENCES `som_properties` (`id`) ON DELETE CASCADE
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

-- som-garage. See the note on som_vehicles for what each of these is for.
CALL som_add_column('som_vehicles', 'owner_group', 'VARCHAR(48) DEFAULT NULL');
CALL som_add_column('som_vehicles', 'group_restricted', 'TINYINT(1) NOT NULL DEFAULT 0');
CALL som_add_column('som_vehicles', 'assigned_to', 'VARCHAR(16) DEFAULT NULL');
CALL som_add_column('som_vehicles', 'taken_at', 'TIMESTAMP NULL DEFAULT NULL');
CALL som_add_column('som_vehicles', 'purchase_price', 'BIGINT NOT NULL DEFAULT 0');

CALL som_add_index('som_vehicles', 'idx_group', '`owner_group`, `state`');
CALL som_add_index('som_vehicles', 'idx_garage', '`garage`, `state`');

DROP PROCEDURE IF EXISTS som_add_column;
DROP PROCEDURE IF EXISTS som_add_index;

-- citizenid becomes NULLABLE so a department pool car can exist without
-- inventing a personal owner for it. Unconditional because MODIFY to the same
-- definition is a no-op, so re-importing costs nothing.
--
-- Not a som_add_column job: that only ADDS columns, and this changes one.
ALTER TABLE `som_vehicles` MODIFY COLUMN `citizenid` VARCHAR(16) DEFAULT NULL;

-- ===========================================================================
--  8c. COMPATIBILITY VIEWS
--
--  ps-mdt is preserved third-party code written against QBCore's schema. It
--  issues 20 queries against `players`, `player_vehicles`, `player_houses` and
--  `apartments`, none of which exist here. Without these views the MDT opens
--  but every profile search, vehicle lookup and property list comes back empty.
--
--  A VIEW rather than 20 edits, for three reasons:
--
--    * ps-mdt stays byte-for-byte preserved, so a future upgrade does not have
--      to have its SQL re-patched.
--    * The mapping lives in ONE place, next to the tables it maps.
--    * The two writes ps-mdt makes (server/dbm.lua:138 and :161, the offline
--      branch of licence revocation) both set `metadata` on a single-table view
--      with no aggregate, union or DISTINCT, which MySQL and MariaDB treat as
--      updatable. The computed `charinfo` column is not itself updatable, and
--      nothing writes it.
--
--  If a MariaDB build ever refuses that UPDATE, point those two call sites at
--  som_characters directly; every read still goes through these views.
-- ===========================================================================

-- qb stores name, DOB and phone inside a `charinfo` JSON blob. SOM stores them
-- as real columns, so the blob is assembled here. ps-mdt reads it with
-- JSON_VALUE(p.charinfo, '$.firstname'), so the key names must match qb's.
CREATE OR REPLACE VIEW `players` AS
SELECT
  `citizenid`,
  `license`,
  `metadata`,
  -- `job` is a JSON OBJECT, not the plain string SOM stores.
  --
  -- ps-mdt does `if type(target.job) == 'string' then json.decode(target.job)`
  -- (server/main.lua:353) because qb keeps a whole job blob in this column.
  -- Handing it the bare string 'police' made that decode fail and took the
  -- entire profile lookup with it, which is why an OFFLINE character's profile
  -- came back empty.
  --
  -- UnpackJob reads name, label and grade.name. The label and grade name live
  -- in som-core/shared/jobs.lua rather than the database, so name is reused for
  -- the label and the grade number is rendered as its name. That is enough for
  -- the MDT to display a profile, and nothing here is used for authority.
  JSON_OBJECT(
    'name',   `job`,
    'label',  `job`,
    'onduty', IF(`job_duty` = 1, TRUE, FALSE),
    'grade',  JSON_OBJECT('level', `job_grade`, 'name', CAST(`job_grade` AS CHAR))
  ) AS `job`,
  JSON_OBJECT(
    'firstname',   `firstname`,
    'lastname',    `lastname`,
    -- Formatted, not raw. A MySQL DATE reaches the client as epoch
    -- milliseconds, which is why the MDT showed 1217721600000 where a date of
    -- birth belonged.
    'birthdate',   DATE_FORMAT(`dob`, '%d/%m/%Y'),
    'gender',      `gender`,
    'nationality', `nationality`,
    'phone',       `phone`
  ) AS `charinfo`
FROM `som_characters`;

-- Column renames: model -> vehicle, props -> mods.
--
-- `state` is the load-bearing one. SOM uses an ENUM; ps-mdt compares against
-- INTEGERS and renders 0 as "Out", 1 as "Garaged", 2 as "Impounded"
-- (ps-mdt/server/main.lua:976-981). Emitting the string here would show a blank
-- status on every vehicle in the MDT, so it is mapped.
CREATE OR REPLACE VIEW `player_vehicles` AS
SELECT
  `id`,
  `citizenid`,
  `plate`,
  `model` AS `vehicle`,
  `props` AS `mods`,
  `garage`,
  `fuel`,
  `engine`,
  `body`,
  CASE `state`
    WHEN 'out'       THEN 0
    WHEN 'garaged'   THEN 1
    WHEN 'impounded' THEN 2
    ELSE 1
  END AS `state`
FROM `som_vehicles`;

-- Housing does not exist in SOM at all. These three return nothing rather than
-- erroring, which is what the MDT's property panel expects. `houselocations` is
-- here because ps-mdt INNER JOINs it, so its absence would fail the query
-- outright rather than return an empty set.
CREATE OR REPLACE VIEW `player_houses` AS
SELECT NULL AS `citizenid`, NULL AS `house` FROM DUAL WHERE FALSE;

CREATE OR REPLACE VIEW `houselocations` AS
SELECT NULL AS `name`, NULL AS `label`, NULL AS `coords` FROM DUAL WHERE FALSE;

CREATE OR REPLACE VIEW `apartments` AS
SELECT NULL AS `citizenid`, NULL AS `name`, NULL AS `type`, NULL AS `label`
FROM DUAL WHERE FALSE;

-- ===========================================================================
--  7e. JAIL AND BAIL (som-jail)
--
--  A sentence has no `remaining_seconds` column. Time served is computed on
--  read as `total_seconds - TIMESTAMPDIFF(SECOND, booked_at, NOW())`, the
--  same "the database is authority, not an in-memory countdown" choice
--  som_property_finance already makes, so a restart cannot lose or stall a
--  countdown and logging out is not a way to dodge a sentence.
--
--  `case_id` is a som_court_cases id (section 7f), a bare number with no FK so
--  the two resources can be imported in either order. There is no link to
--  `mdt_convictions`: that table is preserved third-party and its import can
--  drop and recreate it at any time.
-- ===========================================================================

CREATE TABLE IF NOT EXISTS `som_jail_sentences` (
  `id`             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `citizenid`      VARCHAR(16) NOT NULL,
  `officer_cid`    VARCHAR(16) NOT NULL,
  `case_id`        BIGINT UNSIGNED DEFAULT NULL,
  -- remand is custody before trial. It ends on its own at total_seconds, so
  -- a court that never schedules a hearing cannot hold anyone indefinitely.
  `kind`           ENUM('sentence','remand') NOT NULL DEFAULT 'sentence',
  `charges`        VARCHAR(255) DEFAULT NULL,
  `total_seconds`  INT UNSIGNED NOT NULL,
  -- absconded: left the yard radius while serving. Excluded from the
  -- time-served sweep and from bail eligibility until an officer re-books.
  `status`         ENUM('serving','released','bailed','absconded') NOT NULL DEFAULT 'serving',
  `booked_at`      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `released_at`    TIMESTAMP NULL DEFAULT NULL,
  `released_by`    VARCHAR(16) DEFAULT NULL,
  -- Set when a sentence ends while the citizen is offline, so the next login
  -- sends them to the gate with their property instead of back into a cell.
  `release_pending` TINYINT(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_citizen_status` (`citizenid`, `status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Bail is spent at payment time (it funds the department, like a fine does),
-- not held in escrow, so `forfeited` is a record-keeping flag for an officer
-- glancing at someone's history, not a second money movement. `cleared` just
-- means the 72-hour window passed with no re-arrest; no money moves then
-- either.
CREATE TABLE IF NOT EXISTS `som_jail_bail` (
  `id`             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `sentence_id`    BIGINT UNSIGNED NOT NULL,
  `citizenid`      VARCHAR(16) NOT NULL,
  `amount`         BIGINT NOT NULL DEFAULT 0,
  `status`         ENUM('posted','forfeited','cleared') NOT NULL DEFAULT 'posted',
  `posted_at`      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `appeal_due_at`  DATETIME NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_citizen_status` (`citizenid`, `status`),
  CONSTRAINT `fk_bail_sentence` FOREIGN KEY (`sentence_id`)
    REFERENCES `som_jail_sentences` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ===========================================================================
--  7f. COURT (som-court)
--
--  Every status change is a conditional UPDATE (`... WHERE id = ? AND status =
--  <expected>`) whose affected-row count decides who won, so two clerks acting
--  on the same case cannot both succeed. No FK into any third-party table, and
--  `incident_id` is a bare number kept for an officer's own traceability.
--  Warrants expire by comparing `expires_at` to NOW() when read; the status
--  column is tidied by a sweep, never counted down in memory.
-- ===========================================================================

CREATE TABLE IF NOT EXISTS `som_court_cases` (
  `id`              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `defendant_cid`   VARCHAR(16) NOT NULL,
  `filed_by`        VARCHAR(16) NOT NULL,
  `incident_id`     INT UNSIGNED DEFAULT NULL,
  `charges`         VARCHAR(500) NOT NULL,
  `class`           ENUM('infraction','misdemeanor','felony') NOT NULL,
  `status`          ENUM('filed','accepted','scheduled','convicted','acquitted','dismissed','sentenced') NOT NULL DEFAULT 'filed',
  `prosecutor_cid`  VARCHAR(16) DEFAULT NULL,
  `judge_cid`       VARCHAR(16) DEFAULT NULL,
  `defender_cid`    VARCHAR(16) DEFAULT NULL,
  `hearing_at`      DATETIME DEFAULT NULL,
  `ruled_at`        DATETIME DEFAULT NULL,
  `sentence_months` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  `service_tasks`   SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  `fine`            BIGINT NOT NULL DEFAULT 0,
  `bail_amount`     BIGINT DEFAULT NULL,
  `notes`           VARCHAR(500) DEFAULT NULL,
  `created_at`      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_defendant_status` (`defendant_cid`, `status`),
  KEY `idx_status_hearing` (`status`, `hearing_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `som_court_events` (
  `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `case_id`    BIGINT UNSIGNED NOT NULL,
  `actor_cid`  VARCHAR(16) NOT NULL,
  `action`     VARCHAR(32) NOT NULL,
  `detail`     VARCHAR(255) DEFAULT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_case` (`case_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `som_court_warrants` (
  `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `citizenid`  VARCHAR(16) NOT NULL,
  `case_id`    BIGINT UNSIGNED DEFAULT NULL,
  `reason`     VARCHAR(255) NOT NULL,
  `status`     ENUM('active','served','expired','recalled') NOT NULL DEFAULT 'active',
  `issued_by`  VARCHAR(16) NOT NULL,
  `issued_at`  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `expires_at` DATETIME NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_citizen_status` (`citizenid`, `status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ===========================================================================
--  7g. COMMUNITY SERVICE (som-jail)
--
--  Count based, not a timer, so a restart or a logout cannot change it. A task
--  is counted by one conditional UPDATE that also enforces the gap since the
--  last task, so two quick requests cannot both count. `tasks_total` only ever
--  grows, by the escape penalty, and is capped in config.
-- ===========================================================================

CREATE TABLE IF NOT EXISTS `som_community_service` (
  `id`              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `citizenid`       VARCHAR(16) NOT NULL,
  `case_id`         BIGINT UNSIGNED DEFAULT NULL,
  `issued_by`       VARCHAR(16) NOT NULL,
  `tasks_total`     SMALLINT UNSIGNED NOT NULL,
  `tasks_done`      SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  `strikes`         TINYINT UNSIGNED NOT NULL DEFAULT 0,
  `status`          ENUM('active','completed','cancelled','absconded') NOT NULL DEFAULT 'active',
  `issued_at`       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `completed_at`    TIMESTAMP NULL DEFAULT NULL,
  `last_task_at`    DATETIME DEFAULT NULL,
  `last_penalty_at` DATETIME DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_citizen_status` (`citizenid`, `status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ===========================================================================
--  7h. EVIDENCE (som-evidence)
--
--  The bag an officer carries holds only an evidence id; everything else lives
--  here, so a bag cannot be forged. `profile` is an opaque per-citizen code
--  (som_evidence_profiles), so a lab result can match a sample without ever
--  printing a citizen id. Custody rows are only ever inserted.
-- ===========================================================================

CREATE TABLE IF NOT EXISTS `som_evidence_profiles` (
  `citizenid` VARCHAR(16) NOT NULL,
  `code`      CHAR(8) NOT NULL,
  PRIMARY KEY (`citizenid`),
  UNIQUE KEY `uniq_code` (`code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `som_evidence` (
  `id`            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `kind`          ENUM('casing','blood','fingerprint','dna_sample','print_sample') NOT NULL,
  `status`        ENUM('scene','collected','stored','destroyed') NOT NULL DEFAULT 'scene',
  `x`             DOUBLE NOT NULL,
  `y`             DOUBLE NOT NULL,
  `z`             DOUBLE NOT NULL,
  `holder_cid`    VARCHAR(16) DEFAULT NULL,
  `source_cid`    VARCHAR(16) DEFAULT NULL,
  `profile`       CHAR(8) DEFAULT NULL,
  `weapon_serial` VARCHAR(32) DEFAULT NULL,
  `case_id`       BIGINT UNSIGNED DEFAULT NULL,
  `station`       VARCHAR(32) DEFAULT NULL,
  `created_at`    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `expires_at`    DATETIME NOT NULL,
  `analysed_at`   DATETIME DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_scene` (`status`, `x`, `y`),
  KEY `idx_holder` (`holder_cid`, `status`),
  KEY `idx_case` (`case_id`),
  KEY `idx_profile` (`kind`, `profile`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `som_evidence_custody` (
  `id`          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `evidence_id` BIGINT UNSIGNED NOT NULL,
  `actor_cid`   VARCHAR(16) NOT NULL,
  `action`      VARCHAR(32) NOT NULL,
  `detail`      VARCHAR(255) DEFAULT NULL,
  `created_at`  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_evidence` (`evidence_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ===========================================================================
--  7i. MARKED BILLS AND LAUNDERING (som-launder)
--
--  A marked bill in an inventory is only a pointer to a row here. The worth and
--  the status that count are the row's, never the item's metadata, so a forged
--  or duplicated item washes at most once and a made-up uid washes never.
-- ===========================================================================

CREATE TABLE IF NOT EXISTS `som_marked_bills` (
  `uid`        CHAR(16) NOT NULL,
  `worth`      INT UNSIGNED NOT NULL,
  `status`     ENUM('issued','washing','washed','seized','void') NOT NULL DEFAULT 'issued',
  `order_id`   BIGINT UNSIGNED DEFAULT NULL,
  `source_tag` VARCHAR(32) DEFAULT NULL,
  `issued_at`  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`uid`),
  KEY `idx_order` (`order_id`),
  KEY `idx_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `som_launder_orders` (
  `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `citizenid`  VARCHAR(16) NOT NULL,
  `front`      VARCHAR(32) NOT NULL,
  `face`       BIGINT NOT NULL,
  `payout`     BIGINT NOT NULL,
  `status`     ENUM('washing','collected','cancelled') NOT NULL DEFAULT 'washing',
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `ready_at`   DATETIME NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_citizen_status` (`citizenid`, `status`),
  KEY `idx_created` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

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
  ('GOV-SAN',   'Los Santos Sanitation',          'business', 0),
  ('GOV-DOJ',   'Department of Justice',          'business', 300000),
  ('BUS-LSC',   'Los Santos Customs',             'business', 150000),
  ('BUS-CAB',   'Downtown Cab Co.',               'business', 100000),
  ('BUS-POSTOP','Post OP',                        'business', 100000),
  -- The dealership. Opening float is deliberately large: a managed sale pays
  -- the seller's commission OUT of this account, and a business that cannot
  -- cover the first commission would refuse it and leave the dealer unpaid on
  -- a sale that already went through.
  ('BUS-PDM',   'Premium Deluxe Motorsport',      'business', 250000),
  -- Dynasty 8. Mortgage instalments are collected into this account, so it is
  -- where property debt actually lands rather than vanishing into the economy.
  ('BUS-DYN8',  'Dynasty 8 Real Estate',          'business', 200000);

INSERT IGNORE INTO `som_businesses`
  (`name`, `label`, `job`, `account_id`, `tax_rate`, `funding`, `category`, `active`, `treasury_cut`)
VALUES
  ('lspd',        'Los Santos Police Department', 'police',    (SELECT id FROM som_bank_accounts WHERE account_no='GOV-LSPD'),   0.0000, 'fines',    'government', 1, 0.0000),
  ('bcso',        'Blaine County Sheriff Office', NULL,        (SELECT id FROM som_bank_accounts WHERE account_no='GOV-BCSO'),   0.0000, 'fines',    'government', 0, 0.0000),
  ('sasp',        'San Andreas State Police',     NULL,        (SELECT id FROM som_bank_accounts WHERE account_no='GOV-SASP'),   0.0000, 'fines',    'government', 0, 0.0000),
  -- EMS is funded by the city, not by what it sells. Charging for medical care
  -- would make treatment a paywall.
  ('ems',         'San Andreas Medical Services', 'ambulance', (SELECT id FROM som_bank_accounts WHERE account_no='GOV-EMS'),    0.0000, 'treasury', 'emergency',  1, 0.0000),
  -- The court. Funding is 'fines' so som-economy lets a judge issue one; the
  -- same 70/30 department/treasury split applies and the judge receives nothing.
  -- Sanitation is paid out of the city budget, a capped monthly top-up.
  ('sanitation',  'Los Santos Sanitation',        NULL,        (SELECT id FROM som_bank_accounts WHERE account_no='GOV-SAN'),    0.0000, 'treasury', 'government', 1, 0.0000),
  ('doj',         'Department of Justice',        NULL,        (SELECT id FROM som_bank_accounts WHERE account_no='GOV-DOJ'),    0.0000, 'fines',    'government', 1, 0.0000),
  ('lscustoms',   'Los Santos Customs',           'mechanic',  (SELECT id FROM som_bank_accounts WHERE account_no='BUS-LSC'),    0.0000, 'sales',    'private',    1, 0.0800),
  ('downtowncab', 'Downtown Cab Co.',             'taxi',      (SELECT id FROM som_bank_accounts WHERE account_no='BUS-CAB'),    0.0000, 'sales',    'private',    1, 0.0800),
  ('postop',      'Post OP',                      'delivery',  (SELECT id FROM som_bank_accounts WHERE account_no='BUS-POSTOP'), 0.0000, 'sales',    'private',    1, 0.0800),
  ('pdm',         'Premium Deluxe Motorsport',    'cardealer', (SELECT id FROM som_bank_accounts WHERE account_no='BUS-PDM'),    0.0000, 'sales',    'private',    1, 0.0800),
  ('dynasty8',    'Dynasty 8 Real Estate',        'realtor',   (SELECT id FROM som_bank_accounts WHERE account_no='BUS-DYN8'),   0.0000, 'sales',    'private',    1, 0.0800);

-- Fuel station sales (som-fuel). Opens at zero on purpose: its only income is
-- what players pay at the pump, never a seeded float or treasury money.
INSERT IGNORE INTO `som_bank_accounts` (`account_no`, `label`, `type`, `balance`) VALUES
  ('BUS-FUEL', 'Fuel Station Sales', 'business', 0);

INSERT IGNORE INTO `som_businesses`
  (`name`, `label`, `job`, `account_id`, `tax_rate`, `funding`, `category`, `active`, `treasury_cut`)
VALUES
  ('fuelco', 'Fuel Station Sales', NULL, (SELECT id FROM som_bank_accounts WHERE account_no='BUS-FUEL'), 0.0000, 'sales', 'private', 1, 0.0800);

-- Corrections for databases seeded before the funding model existed, where
-- INSERT IGNORE above skipped the rows and left them on column defaults.
UPDATE `som_businesses`
   SET `funding` = 'fines', `category` = 'government', `active` = 1,
       `account_id` = (SELECT id FROM som_bank_accounts WHERE account_no = 'GOV-LSPD')
 WHERE `name` = 'lspd';

UPDATE `som_businesses` SET `funding` = 'treasury', `category` = 'emergency' WHERE `name` = 'ems';

UPDATE `som_businesses` SET `funding` = 'sales', `category` = 'private', `treasury_cut` = 0.0800
 WHERE `name` IN ('lscustoms', 'downtowncab', 'postop', 'pdm');

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

-- ===========================================================================
--  7j. HEISTS (som-heists)
--
--  A dongle is an item that points at a row here; the row decides whether it
--  still works. A run row claims a site with one conditional insert and doubles
--  as the cooldown and the hourly clean cash cap.
-- ===========================================================================

CREATE TABLE IF NOT EXISTS `som_heist_dongles` (
  `uid`        CHAR(16) NOT NULL,
  `status`     ENUM('issued','used','void') NOT NULL DEFAULT 'issued',
  `source_tag` VARCHAR(32) NOT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`uid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `som_heist_runs` (
  `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `site`       VARCHAR(32) NOT NULL,
  `tier`       ENUM('store','bank','vault') NOT NULL,
  `group_id`   INT UNSIGNED NOT NULL,
  `status`     ENUM('active','done','failed') NOT NULL DEFAULT 'active',
  `clean_paid` BIGINT NOT NULL DEFAULT 0,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_site` (`site`, `created_at`),
  KEY `idx_tier` (`tier`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ===========================================================================
--  7k. TURF AND THE DRUG MARKET (som-turf)
--
--  som_turf and som_turf_events are in section 4 and are seeded by som-turf at
--  boot. This table holds how many units of each drug were sold recently; the
--  price recovers by timestamp, so a restart changes nothing.
-- ===========================================================================

CREATE TABLE IF NOT EXISTS `som_drug_market` (
  `item`       VARCHAR(48) NOT NULL,
  `units`      INT UNSIGNED NOT NULL DEFAULT 0,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`item`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ===========================================================================
--  7l. STAFF (som-staff)
-- ===========================================================================

CREATE TABLE IF NOT EXISTS `som_whitelist` (
  `identifier` VARCHAR(64) NOT NULL,
  `note`       VARCHAR(120) NOT NULL DEFAULT '',
  `added_by`   VARCHAR(64) NOT NULL DEFAULT 'console',
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `som_reports` (
  `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `citizenid`  VARCHAR(16) NOT NULL,
  `name`       VARCHAR(64) NOT NULL,
  `message`    VARCHAR(200) NOT NULL,
  `status`     ENUM('open','claimed','closed') NOT NULL DEFAULT 'open',
  `claimed_by` VARCHAR(32) DEFAULT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_status` (`status`, `id`),
  KEY `idx_citizen` (`citizenid`, `status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `som_staff_audit` (
  `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `staff`      VARCHAR(32) NOT NULL,
  `action`     VARCHAR(32) NOT NULL,
  `target`     VARCHAR(48) DEFAULT NULL,
  `detail`     VARCHAR(200) DEFAULT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_staff` (`staff`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `som_gang_log` (
  `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `gang`       VARCHAR(32) NOT NULL,
  `actor`      VARCHAR(16) DEFAULT NULL,
  `target`     VARCHAR(16) DEFAULT NULL,
  `action`     VARCHAR(24) NOT NULL,
  `detail`     VARCHAR(120) DEFAULT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_gang_time` (`gang`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Weed plants (som-turf). Stage is worked out from the timestamps.
CREATE TABLE IF NOT EXISTS `som_plants` (
  `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `citizenid`  VARCHAR(16) NOT NULL,
  `strain`     VARCHAR(48) NOT NULL,
  `x`          DOUBLE NOT NULL,
  `y`          DOUBLE NOT NULL,
  `z`          DOUBLE NOT NULL,
  `fed`        TINYINT(1) NOT NULL DEFAULT 0,
  `status`     ENUM('growing','harvested','withered') NOT NULL DEFAULT 'growing',
  `planted_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `last_water` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_status` (`status`),
  KEY `idx_owner` (`citizenid`, `status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Lab cooks (som-turf). ready_at comes from the database clock.
CREATE TABLE IF NOT EXISTS `som_lab_jobs` (
  `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `citizenid`  VARCHAR(16) NOT NULL,
  `lab`        VARCHAR(32) NOT NULL,
  `recipe`     VARCHAR(32) NOT NULL,
  `status`     ENUM('cooking','collected') NOT NULL DEFAULT 'cooking',
  `ready_at`   TIMESTAMP NOT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_lab` (`lab`, `status`),
  KEY `idx_owner` (`citizenid`, `status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Buyer payouts (som-outdoors). The hourly cap is the sum of the last hour.
CREATE TABLE IF NOT EXISTS `som_buyer_payouts` (
  `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `buyer`      VARCHAR(32) NOT NULL,
  `amount`     BIGINT NOT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_buyer_time` (`buyer`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Chopped vehicles (som-outdoors). Doubles as the drop-off and plate cooldown.
CREATE TABLE IF NOT EXISTS `som_chop_log` (
  `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `citizenid`  VARCHAR(16) NOT NULL,
  `dropoff`    VARCHAR(32) NOT NULL,
  `plate`      VARCHAR(12) NOT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_dropoff` (`dropoff`, `created_at`),
  KEY `idx_plate` (`plate`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- New life records (som-medical). until_at comes from the database clock.
CREATE TABLE IF NOT EXISTS `som_new_life` (
  `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `citizenid`  VARCHAR(16) NOT NULL,
  `class`      ENUM('violence','accident') NOT NULL,
  `x`          DOUBLE NOT NULL,
  `y`          DOUBLE NOT NULL,
  `z`          DOUBLE NOT NULL,
  `until_at`   TIMESTAMP NOT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_citizen` (`citizenid`, `until_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Bans (som-staff). One row per identifier; expires_at NULL is permanent.
CREATE TABLE IF NOT EXISTS `som_bans` (
  `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `identifier` VARCHAR(64) NOT NULL,
  `reason`     VARCHAR(120) NOT NULL,
  `banned_by`  VARCHAR(32) NOT NULL,
  `revoked`    TINYINT(1) NOT NULL DEFAULT 0,
  `expires_at` TIMESTAMP NULL DEFAULT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_identifier` (`identifier`, `revoked`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Skill experience (som-progress). Levels are computed from xp, never stored.
CREATE TABLE IF NOT EXISTS `som_skills` (
  `citizenid` VARCHAR(16) NOT NULL,
  `track`     VARCHAR(24) NOT NULL,
  `xp`        BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `day_xp`    INT UNSIGNED NOT NULL DEFAULT 0,
  `day`       DATE NOT NULL,
  PRIMARY KEY (`citizenid`, `track`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Mechanic offers and roadside sales (som-mechanic). 'FALLBACK' as seller marks a roadside desk sale.
CREATE TABLE IF NOT EXISTS `som_trade_offers` (
  `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `seller`     VARCHAR(16) NOT NULL,
  `buyer`      VARCHAR(16) NOT NULL,
  `item`       VARCHAR(48) NOT NULL,
  `price`      BIGINT NOT NULL,
  `status`     ENUM('pending','done','cancelled') NOT NULL DEFAULT 'pending',
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_buyer` (`buyer`, `status`),
  KEY `idx_seller` (`seller`, `status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Staff placed positions for content that ships disabled (som-staff /place). The content
-- resource applies a row over its Config by path when it starts.
CREATE TABLE IF NOT EXISTS `som_placements` (
  `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `resource`   VARCHAR(32) NOT NULL,
  `path`       VARCHAR(80) NOT NULL,
  `kind`       ENUM('point','number','bool') NOT NULL,
  `value`      VARCHAR(200) NOT NULL,
  `placed_by`  VARCHAR(32) NOT NULL DEFAULT 'console',
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_resource` (`resource`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Player-run shops (som-shops). A shop is bought from the city, stocked and priced by its owner,
-- and staffed by hired players. Its takings go to its own business account (`shop_<id>`).
CREATE TABLE IF NOT EXISTS `som_shops` (
  `shop_id`      VARCHAR(32) NOT NULL,
  `business`     VARCHAR(48) NOT NULL,
  `owner`        VARCHAR(16) DEFAULT NULL,
  `bought_price` BIGINT NOT NULL DEFAULT 0,
  `bought_at`    TIMESTAMP NULL DEFAULT NULL,
  `withdraw_at`  TIMESTAMP NULL DEFAULT NULL,
  PRIMARY KEY (`shop_id`),
  KEY `idx_owner` (`owner`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `som_shop_stock` (
  `shop_id` VARCHAR(32) NOT NULL,
  `item`    VARCHAR(48) NOT NULL,
  `qty`     INT UNSIGNED NOT NULL DEFAULT 0,
  `price`   BIGINT NOT NULL,
  PRIMARY KEY (`shop_id`, `item`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- One job per character (the primary key), paid hourly from the shop account. last_paid_at is
-- claimed with a conditional UPDATE so two ticks or a restart cannot pay twice.
CREATE TABLE IF NOT EXISTS `som_shop_staff` (
  `citizenid`    VARCHAR(16) NOT NULL,
  `shop_id`      VARCHAR(32) NOT NULL,
  `hourly_pay`   BIGINT NOT NULL,
  `last_paid_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`citizenid`),
  KEY `idx_shop` (`shop_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
-- ===========================================================================
--  7n. COURT SERVICE (som-serving)
--
--  One row per case, and `case_id` is UNIQUE: the insert that creates it is the
--  claim, so two servers cannot both be paid for the same papers. The hourly
--  cap and the per-defendant cooldown are read from this table, not memory.
-- ===========================================================================

CREATE TABLE IF NOT EXISTS `som_court_service` (
  `id`            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `case_id`       BIGINT UNSIGNED NOT NULL,
  `defendant_cid` VARCHAR(16) NOT NULL,
  `server_cid`    VARCHAR(16) NOT NULL,
  `fee`           BIGINT NOT NULL,
  `served_at`     TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_case` (`case_id`),
  KEY `idx_defendant_time` (`defendant_cid`, `served_at`),
  KEY `idx_server_time` (`server_cid`, `served_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ===========================================================================
--  7m. LICENCES AND DRIVING SCHOOL (som-licences)
--
--  Licences themselves stay in som_licenses (suspended_until above). This only
--  records test attempts, so a failed theory test can carry a retry cooldown
--  that survives a restart.
-- ===========================================================================

CREATE TABLE IF NOT EXISTS `som_licence_attempts` (
  `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `citizenid`  VARCHAR(16) NOT NULL,
  `kind`       ENUM('theory','practical') NOT NULL,
  `passed`     TINYINT(1)  NOT NULL DEFAULT 0,
  `score`      SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  `created_at` TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_citizen_kind` (`citizenid`, `kind`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- One-time backfill for databases that already have licence holders. Before
-- som-licences the weapon licence existed only as metadata, and logging in now
-- rebuilds that metadata from som_licenses, so without these rows existing
-- holders lose the licence. Run once; INSERT IGNORE makes a repeat harmless.
-- INSERT IGNORE INTO som_licenses (citizenid, type, issued_by)
--   SELECT citizenid, 'weapon', 'legacy' FROM som_characters
--   WHERE JSON_VALUE(metadata, '$.licenses.weapon') = 'true';
-- INSERT IGNORE INTO som_licenses (citizenid, type, issued_by)
--   SELECT citizenid, 'driver', 'legacy' FROM som_characters
--   WHERE JSON_VALUE(metadata, '$.licenses.driver') = 'true';
