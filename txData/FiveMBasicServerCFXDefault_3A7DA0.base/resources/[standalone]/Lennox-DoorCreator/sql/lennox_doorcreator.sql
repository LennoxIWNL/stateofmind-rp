-- Lennox Door Creator v1.0.0
-- Main schema — run this on first install

CREATE TABLE IF NOT EXISTS `lennox_buildings` (
    `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
    `name` varchar(100) NOT NULL,
    `description` text DEFAULT NULL,
    `doors` longtext NOT NULL,
    `permissions` longtext DEFAULT NULL,
    `metadata` longtext DEFAULT NULL,
    `created_by` varchar(100) DEFAULT NULL,
    `created_at` timestamp DEFAULT CURRENT_TIMESTAMP,
    `updated_at` timestamp DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `lennox_templates` (
    `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
    `name` varchar(100) NOT NULL,
    `description` text DEFAULT NULL,
    `type` enum('single', 'building') NOT NULL DEFAULT 'single',
    `data` longtext NOT NULL,
    `author` varchar(100) DEFAULT NULL,
    `version` varchar(20) DEFAULT '1.0.0',
    `export_code` varchar(32) DEFAULT NULL,
    `created_at` timestamp DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `export_code` (`export_code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `lennox_backups` (
    `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
    `name` varchar(100) NOT NULL,
    `type` enum('auto', 'manual') NOT NULL DEFAULT 'auto',
    `door_count` int(11) NOT NULL DEFAULT 0,
    `building_count` int(11) NOT NULL DEFAULT 0,
    `data` longtext NOT NULL,
    `created_by` varchar(100) DEFAULT NULL,
    `created_at` timestamp DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `lennox_door_logs` (
    `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
    `action` varchar(50) NOT NULL,
    `door_id` int(11) DEFAULT NULL,
    `building_id` int(11) DEFAULT NULL,
    `player_name` varchar(100) DEFAULT NULL,
    `player_identifier` varchar(100) DEFAULT NULL,
    `details` longtext DEFAULT NULL,
    `created_at` timestamp DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_action` (`action`),
    KEY `idx_door_id` (`door_id`),
    KEY `idx_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
