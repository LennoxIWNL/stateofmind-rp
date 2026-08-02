-- SOM Framework core schema.
-- Every table is prefixed som_ so it can coexist with the legacy qbx tables
-- during migration. Nothing here reads or writes a qbx table.
--
-- Apply with: mysql -u user -p stateofmindrp < som_schema.sql

-- ---------------------------------------------------------------------------
-- Identity
-- ---------------------------------------------------------------------------

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

-- ---------------------------------------------------------------------------
-- Money
--
-- Balances live here, one row per character. They are only ever written by
-- som-core/server/money.lua, never by a job or gameplay script directly.
-- ---------------------------------------------------------------------------

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
-- Phase 4 sink/faucet analysis and anti-dupe investigation both query this.
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

-- Bank accounts beyond the personal one: business, shared, offshore.
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

-- ---------------------------------------------------------------------------
-- Jobs
--
-- Job definitions are config (som-core/shared/jobs.lua). These tables hold
-- runtime state only: who applied, and the business register Phase 4 taxes.
-- ---------------------------------------------------------------------------

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
  `created_at`   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_name` (`name`),
  KEY `idx_job` (`job`),
  CONSTRAINT `fk_business_account` FOREIGN KEY (`account_id`) REFERENCES `som_bank_accounts` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Phase 5 requires applying at an NPC, not a /job command. This is that queue.
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

-- The state treasury Phase 4 makes visible to players.
CREATE TABLE IF NOT EXISTS `som_treasury` (
  `id`       TINYINT UNSIGNED NOT NULL DEFAULT 1,
  `balance`  BIGINT NOT NULL DEFAULT 0,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
INSERT IGNORE INTO `som_treasury` (`id`, `balance`) VALUES (1, 0);

-- ---------------------------------------------------------------------------
-- Gangs and turf (Phase 6 is greenfield, these are the anchors)
-- ---------------------------------------------------------------------------

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

-- Per-gang rank labels, carried over from som-gangboss-app's custom ranks.
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

-- Append-only log of control point changes, so turf swings are auditable
-- and a HUD can show recent activity without polling live state.
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

-- ---------------------------------------------------------------------------
-- Vehicles and licences
-- ---------------------------------------------------------------------------

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

-- ---------------------------------------------------------------------------
-- Seed data
--
-- Payroll debits a business account rather than minting money, so every job in
-- som-core/shared/jobs.lua that declares a `business` needs a funded account or
-- nobody on that job gets paid at all.
--
-- The opening balances below are PLACEHOLDER FLOAT, not a balance decision.
-- Phase 4 replaces them with real revenue: businesses earn from player activity
-- and are taxed into som_treasury. See AUDIT.md section 12.2, the tax rate and
-- sink/faucet ratio are still open questions.
-- ---------------------------------------------------------------------------

INSERT IGNORE INTO `som_bank_accounts` (`account_no`, `label`, `type`, `balance`) VALUES
  ('BUS-LSPD',    'Los Santos Police Department', 'business', 500000),
  ('BUS-PILLBOX', 'Pillbox Medical Center',       'business', 500000),
  ('BUS-LSC',     'Los Santos Customs',           'business', 150000),
  ('BUS-CAB',     'Downtown Cab Co.',             'business', 100000),
  ('BUS-POSTOP',  'Post OP',                      'business', 100000);

INSERT IGNORE INTO `som_businesses` (`name`, `label`, `job`, `account_id`, `tax_rate`) VALUES
  ('lspd',        'Los Santos Police Department', 'police',    (SELECT id FROM som_bank_accounts WHERE account_no = 'BUS-LSPD'),    0.0000),
  ('pillbox',     'Pillbox Medical Center',       'ambulance', (SELECT id FROM som_bank_accounts WHERE account_no = 'BUS-PILLBOX'), 0.0000),
  ('lscustoms',   'Los Santos Customs',           'mechanic',  (SELECT id FROM som_bank_accounts WHERE account_no = 'BUS-LSC'),     0.0000),
  ('downtowncab', 'Downtown Cab Co.',             'taxi',      (SELECT id FROM som_bank_accounts WHERE account_no = 'BUS-CAB'),     0.0000),
  ('postop',      'Post OP',                      'delivery',  (SELECT id FROM som_bank_accounts WHERE account_no = 'BUS-POSTOP'),  0.0000);

-- Gangs listed in som-core/shared/gangs.lua. Turf rows are Phase 6.
INSERT IGNORE INTO `som_gangs` (`name`, `label`, `color`) VALUES
  ('none',    'No Gang',      '#666666'),
  ('lostmc',  'The Lost MC',  '#8b1a1a'),
  ('ballas',  'Ballas',       '#6b3fa0'),
  ('vagos',   'Vagos',        '#d4a017'),
  ('families','Families',     '#2e8b57'),
  ('cartel',  'Cartel',       '#b8860b');
