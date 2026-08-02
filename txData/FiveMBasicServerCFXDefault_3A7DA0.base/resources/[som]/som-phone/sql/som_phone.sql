-- SOM phone, Phase 4b.
--
-- Additive and safe to re-run. Apply after som_schema.sql.
--
-- Deliberately small: there is no messages, contacts or calls table yet, and no
-- separate account model. The bank app reads som_transactions and
-- som_bank_accounts directly, which is the whole reason for building the phone
-- rather than adopting one with its own schema.

-- ---------------------------------------------------------------------------
-- Bills
--
-- A bill is a REQUEST, never a withdrawal. Money moves only when the recipient
-- accepts. Anything else means a leaked account number is a way to empty
-- somebody's balance without their consent.
-- ---------------------------------------------------------------------------

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
  `created_at`  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `settled_at`  TIMESTAMP    NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_to_status` (`to_citizenid`, `status`),
  KEY `idx_from` (`from_citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------------
-- Saved account numbers
--
-- What a player keeps after someone shares their number with them. Separate
-- from contacts, which do not exist yet.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS `som_phone_accounts` (
  `citizenid`  VARCHAR(16) NOT NULL,
  `account_no` VARCHAR(24) NOT NULL,
  `label`      VARCHAR(72) NOT NULL,
  `saved_at`   TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`citizenid`, `account_no`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------------
-- Per-character phone settings
--
-- Theme and wallpaper are supporter perks (patreon.md), so what is stored here
-- is validated server side against the player's entitlements rather than
-- trusted from the client.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS `som_phone_settings` (
  `citizenid`  VARCHAR(16) NOT NULL,
  `theme`      VARCHAR(32) NOT NULL DEFAULT 'default',
  `wallpaper`  VARCHAR(64) NOT NULL DEFAULT 'default',
  `updated_at` TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Personal bank accounts.
--
-- som_bank_accounts already existed for businesses and gangs. Every character
-- needs one so they have a shareable number, which is what the bank app is
-- built around. Created lazily by som-phone on first open rather than
-- backfilled here, so a character that never opens the app never gets a row.
