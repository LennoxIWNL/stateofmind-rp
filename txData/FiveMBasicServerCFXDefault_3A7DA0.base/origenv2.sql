-- --------------------------------------------------------
-- Host:                         127.0.0.1
-- Server version:               10.4.32-MariaDB - mariadb.org binary distribution
-- Server OS:                    Win64
-- HeidiSQL Version:             12.6.0.6765
-- --------------------------------------------------------

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET NAMES utf8 */;
/*!50503 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;


-- Dumping database structure for origenv2qb
CREATE DATABASE IF NOT EXISTS `origenv2qb` /*!40100 DEFAULT CHARACTER SET utf8 COLLATE utf8_general_ci */;
USE `origenv2qb`;

-- Dumping structure for table origenv2qb.accounts
CREATE TABLE IF NOT EXISTS `accounts` (
  `identifier` varchar(50) NOT NULL,
  `id` varchar(50) NOT NULL DEFAULT '',
  `name` longtext NOT NULL,
  `balance` bigint(20) NOT NULL DEFAULT 0,
  `transactions` longtext NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

-- Dumping data for table origenv2qb.accounts: ~0 rows (approximately)

-- Dumping structure for table origenv2qb.apartments
CREATE TABLE IF NOT EXISTS `apartments` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(255) DEFAULT NULL,
  `type` varchar(255) DEFAULT NULL,
  `label` varchar(255) DEFAULT NULL,
  `citizenid` varchar(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `citizenid` (`citizenid`),
  KEY `name` (`name`)
) ENGINE=InnoDB AUTO_INCREMENT=33 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Dumping data for table origenv2qb.apartments: ~0 rows (approximately)

-- Dumping structure for table origenv2qb.bank_accounts
CREATE TABLE IF NOT EXISTS `bank_accounts` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `citizenid` varchar(11) DEFAULT NULL,
  `account_name` varchar(50) DEFAULT NULL,
  `account_balance` int(11) NOT NULL DEFAULT 0,
  `account_type` enum('shared','job','gang') NOT NULL,
  `users` longtext DEFAULT '[]',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE KEY `account_name` (`account_name`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Dumping data for table origenv2qb.bank_accounts: ~0 rows (approximately)

-- Dumping structure for table origenv2qb.bank_statements
CREATE TABLE IF NOT EXISTS `bank_statements` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `citizenid` varchar(11) DEFAULT NULL,
  `account_name` varchar(50) DEFAULT 'checking',
  `amount` int(11) DEFAULT NULL,
  `reason` varchar(50) DEFAULT NULL,
  `statement_type` enum('deposit','withdraw') DEFAULT NULL,
  `date` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`) USING BTREE,
  KEY `citizenid` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Dumping data for table origenv2qb.bank_statements: ~0 rows (approximately)

-- Dumping structure for table origenv2qb.bans
CREATE TABLE IF NOT EXISTS `bans` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(50) DEFAULT NULL,
  `license` varchar(50) DEFAULT NULL,
  `discord` varchar(50) DEFAULT NULL,
  `ip` varchar(50) DEFAULT NULL,
  `reason` text DEFAULT NULL,
  `expire` int(11) DEFAULT NULL,
  `bannedby` varchar(255) NOT NULL DEFAULT 'LeBanhammer',
  PRIMARY KEY (`id`),
  KEY `license` (`license`),
  KEY `discord` (`discord`),
  KEY `ip` (`ip`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Dumping data for table origenv2qb.bans: ~0 rows (approximately)

-- Dumping structure for table origenv2qb.crypto
CREATE TABLE IF NOT EXISTS `crypto` (
  `crypto` varchar(50) NOT NULL DEFAULT 'qbit',
  `worth` int(11) NOT NULL DEFAULT 0,
  `history` text DEFAULT NULL,
  PRIMARY KEY (`crypto`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

-- Dumping data for table origenv2qb.crypto: ~1 rows (approximately)
INSERT INTO `crypto` (`crypto`, `worth`, `history`) VALUES
	('qbit', 961, '[{"PreviousWorth":965,"NewWorth":962},{"PreviousWorth":965,"NewWorth":962},{"PreviousWorth":965,"NewWorth":962},{"PreviousWorth":962,"NewWorth":961}]');

-- Dumping structure for table origenv2qb.cryptominers
CREATE TABLE IF NOT EXISTS `cryptominers` (
  `citizenid` varchar(50) NOT NULL,
  `card` varchar(50) NOT NULL,
  `balance` double NOT NULL,
  PRIMARY KEY (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

-- Dumping data for table origenv2qb.cryptominers: ~1 rows (approximately)
INSERT INTO `cryptominers` (`citizenid`, `card`, `balance`) VALUES
	('ZEN90470', '4090gpu', 0);

-- Dumping structure for table origenv2qb.crypto_transactions
CREATE TABLE IF NOT EXISTS `crypto_transactions` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `citizenid` varchar(50) DEFAULT NULL,
  `title` varchar(50) DEFAULT NULL,
  `message` varchar(50) DEFAULT NULL,
  `date` timestamp NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `citizenid` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Dumping data for table origenv2qb.crypto_transactions: ~0 rows (approximately)

-- Dumping structure for table origenv2qb.darkchat_messages
CREATE TABLE IF NOT EXISTS `darkchat_messages` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `owner` varchar(50) DEFAULT NULL,
  `name` varchar(50) DEFAULT '',
  `messages` text DEFAULT NULL,
  PRIMARY KEY (`id`) USING BTREE,
  KEY `id` (`id`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=10 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Dumping data for table origenv2qb.darkchat_messages: ~0 rows (approximately)

-- Dumping structure for table origenv2qb.dealers
CREATE TABLE IF NOT EXISTS `dealers` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(50) NOT NULL DEFAULT '0',
  `coords` longtext DEFAULT NULL,
  `time` longtext DEFAULT NULL,
  `createdby` varchar(50) NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Dumping data for table origenv2qb.dealers: ~0 rows (approximately)

-- Dumping structure for table origenv2qb.debux_petshop
CREATE TABLE IF NOT EXISTS `debux_petshop` (
  `identifier` varchar(50) DEFAULT NULL,
  `pet_code` varchar(50) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Dumping data for table origenv2qb.debux_petshop: ~0 rows (approximately)

-- Dumping structure for table origenv2qb.elixir_clothing
CREATE TABLE IF NOT EXISTS `elixir_clothing` (
  `id` int(25) NOT NULL AUTO_INCREMENT,
  `cid` int(11) DEFAULT 0,
  `model` varchar(50) NOT NULL DEFAULT '',
  `drawables_texture` text NOT NULL,
  `props_texture` text NOT NULL,
  `hairColor` text NOT NULL,
  `fadeLayer` text DEFAULT '0',
  `customHeadModel` text NOT NULL DEFAULT 'false',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=29 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Dumping data for table origenv2qb.elixir_clothing: ~1 rows (approximately)

-- Dumping structure for table origenv2qb.elixir_head_clothing
CREATE TABLE IF NOT EXISTS `elixir_head_clothing` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `cid` int(11) NOT NULL,
  `model` varchar(50) DEFAULT NULL,
  `head_blend` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL,
  `head_features` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL,
  `head_overlays` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL,
  `fade` longtext DEFAULT '""',
  `eye_color` int(11) NOT NULL DEFAULT 0,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`) USING BTREE,
  CONSTRAINT `head_blend` CHECK (json_valid(`head_blend`)),
  CONSTRAINT `head_features` CHECK (json_valid(`head_features`)),
  CONSTRAINT `head_overlays` CHECK (json_valid(`head_overlays`))
) ENGINE=InnoDB AUTO_INCREMENT=10 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Dumping data for table origenv2qb.elixir_head_clothing: ~0 rows (approximately)

-- Dumping structure for table origenv2qb.elixir_outfits
CREATE TABLE IF NOT EXISTS `elixir_outfits` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `cid` int(11) DEFAULT NULL,
  `name` varchar(255) DEFAULT NULL,
  `tags` varchar(255) DEFAULT NULL,
  `slot` int(11) DEFAULT NULL,
  `model` varchar(255) DEFAULT NULL,
  `drawables_texture` text DEFAULT NULL,
  `props_texture` text DEFAULT NULL,
  `hairColor` text DEFAULT NULL,
  `fadeLayer` text DEFAULT NULL,
  `customHeadModel` varchar(255) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE KEY `unique_cid_slot` (`cid`,`slot`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=31 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Dumping data for table origenv2qb.elixir_outfits: ~0 rows (approximately)

-- Dumping structure for table origenv2qb.evidence_storage
CREATE TABLE IF NOT EXISTS `evidence_storage` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `data` longtext NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Dumping data for table origenv2qb.evidence_storage: ~0 rows (approximately)

-- Dumping structure for table origenv2qb.fuel_stations
CREATE TABLE IF NOT EXISTS `fuel_stations` (
  `location` int(11) NOT NULL,
  `owned` int(11) DEFAULT NULL,
  `owner` varchar(50) DEFAULT NULL,
  `fuel` int(11) DEFAULT NULL,
  `fuelprice` int(11) DEFAULT NULL,
  `balance` int(255) DEFAULT NULL,
  `label` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`location`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

-- Dumping data for table origenv2qb.fuel_stations: ~0 rows (approximately)

-- Dumping structure for table origenv2qb.gfx_racing
CREATE TABLE IF NOT EXISTS `gfx_racing` (
  `identifier` varchar(50) DEFAULT NULL,
  `routes` longtext DEFAULT NULL,
  `racehistory` longtext DEFAULT NULL,
  `win` int(11) DEFAULT NULL,
  `lose` int(11) DEFAULT NULL,
  `favouritecar` longtext DEFAULT NULL,
  `distance` bigint(20) DEFAULT NULL,
  `charname` varchar(50) DEFAULT NULL,
  `incomingrace` int(11) DEFAULT NULL,
  `lastrace` varchar(50) DEFAULT NULL,
  `playerphoto` longtext DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

-- Dumping data for table origenv2qb.gfx_racing: ~0 rows (approximately)

-- Dumping structure for table origenv2qb.gloveboxitems
CREATE TABLE IF NOT EXISTS `gloveboxitems` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `plate` varchar(8) NOT NULL DEFAULT '[]',
  `items` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL,
  PRIMARY KEY (`plate`),
  KEY `id` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Dumping data for table origenv2qb.gloveboxitems: ~0 rows (approximately)

-- Dumping structure for table origenv2qb.houselocations
CREATE TABLE IF NOT EXISTS `houselocations` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(255) DEFAULT NULL,
  `label` varchar(255) DEFAULT NULL,
  `coords` text DEFAULT NULL,
  `owned` tinyint(1) DEFAULT NULL,
  `price` int(11) DEFAULT NULL,
  `tier` tinyint(4) DEFAULT NULL,
  `garage` text DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `name` (`name`)
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Dumping data for table origenv2qb.houselocations: ~1 rows (approximately)
INSERT INTO `houselocations` (`id`, `name`, `label`, `coords`, `owned`, `price`, `tier`, `garage`) VALUES
	(3, 'south rockford dr1', 'South Rockford Dr 1', '{"cam":{"yaw":-10.0,"z":2.24340415000915,"x":-900.8446044921875,"h":122.48832702636719,"y":-982.3162231445313},"enter":{"z":2.24340415000915,"h":122.48832702636719,"x":-900.8446044921875,"y":-982.3162231445313}}', 1, 1, 3, NULL);

-- Dumping structure for table origenv2qb.house_plants
CREATE TABLE IF NOT EXISTS `house_plants` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `building` varchar(50) DEFAULT NULL,
  `stage` varchar(50) DEFAULT 'stage-a',
  `sort` varchar(50) DEFAULT NULL,
  `gender` varchar(50) DEFAULT NULL,
  `food` int(11) DEFAULT 100,
  `health` int(11) DEFAULT 100,
  `progress` int(11) DEFAULT 0,
  `coords` text DEFAULT NULL,
  `plantid` varchar(50) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `building` (`building`),
  KEY `plantid` (`plantid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Dumping data for table origenv2qb.house_plants: ~0 rows (approximately)

-- Dumping structure for table origenv2qb.instagram_account
CREATE TABLE IF NOT EXISTS `instagram_account` (
  `id` varchar(90) NOT NULL,
  `name` varchar(50) NOT NULL,
  `phone` varchar(50) NOT NULL,
  `username` varchar(50) NOT NULL,
  `password` varchar(50) NOT NULL,
  `avatar` text DEFAULT NULL,
  `description` text DEFAULT NULL,
  `verify` int(11) NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Dumping data for table origenv2qb.instagram_account: ~0 rows (approximately)

-- Dumping structure for table origenv2qb.instagram_followers
CREATE TABLE IF NOT EXISTS `instagram_followers` (
  `username` varchar(50) NOT NULL,
  `followed` varchar(50) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Dumping data for table origenv2qb.instagram_followers: ~0 rows (approximately)

-- Dumping structure for table origenv2qb.instagram_posts
CREATE TABLE IF NOT EXISTS `instagram_posts` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `username` varchar(50) NOT NULL,
  `image` text NOT NULL,
  `description` varchar(255) NOT NULL,
  `location` varchar(50) NOT NULL,
  `filter` varchar(50) NOT NULL,
  `created` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `likes` text DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=14 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Dumping data for table origenv2qb.instagram_posts: ~0 rows (approximately)

-- Dumping structure for table origenv2qb.instagram_stories
CREATE TABLE IF NOT EXISTS `instagram_stories` (
  `owner` varchar(50) NOT NULL,
  `data` text DEFAULT NULL,
  PRIMARY KEY (`owner`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=armscii8 COLLATE=armscii8_bin;

-- Dumping data for table origenv2qb.instagram_stories: ~0 rows (approximately)

-- Dumping structure for table origenv2qb.insta_stories
CREATE TABLE IF NOT EXISTS `insta_stories` (
  `username` varchar(50) DEFAULT NULL,
  `location` varchar(50) DEFAULT NULL,
  `filter` varchar(50) DEFAULT NULL,
  `description` varchar(50) DEFAULT NULL,
  `image` text DEFAULT NULL,
  `created` time DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Dumping data for table origenv2qb.insta_stories: ~0 rows (approximately)

-- Dumping structure for table origenv2qb.kloud_delivery
CREATE TABLE IF NOT EXISTS `kloud_delivery` (
  `job` varchar(55) NOT NULL,
  `stock` int(11) NOT NULL DEFAULT 1,
  PRIMARY KEY (`job`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

-- Dumping data for table origenv2qb.kloud_delivery: ~1 rows (approximately)
INSERT INTO `kloud_delivery` (`job`, `stock`) VALUES
	('burgershot', 9);

-- Dumping structure for table origenv2qb.lapraces
CREATE TABLE IF NOT EXISTS `lapraces` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(50) DEFAULT NULL,
  `checkpoints` text DEFAULT NULL,
  `records` text DEFAULT NULL,
  `creator` varchar(50) DEFAULT NULL,
  `distance` int(11) DEFAULT NULL,
  `raceid` varchar(50) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `raceid` (`raceid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Dumping data for table origenv2qb.lapraces: ~0 rows (approximately)

-- Dumping structure for table origenv2qb.management_funds
CREATE TABLE IF NOT EXISTS `management_funds` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `job_name` varchar(50) NOT NULL,
  `amount` int(100) NOT NULL,
  `type` enum('boss','gang') NOT NULL DEFAULT 'boss',
  PRIMARY KEY (`id`),
  UNIQUE KEY `job_name` (`job_name`),
  KEY `type` (`type`)
) ENGINE=InnoDB AUTO_INCREMENT=14 DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

-- Dumping data for table origenv2qb.management_funds: ~12 rows (approximately)
INSERT INTO `management_funds` (`id`, `job_name`, `amount`, `type`) VALUES
	(1, 'police', 0, 'boss'),
	(2, 'ambulance', 0, 'boss'),
	(3, 'realestate', 0, 'boss'),
	(4, 'taxi', 0, 'boss'),
	(5, 'cardealer', 0, 'boss'),
	(6, 'mechanic', 0, 'boss'),
	(7, 'lostmc', 0, 'gang'),
	(8, 'ballas', 0, 'gang'),
	(9, 'vagos', 0, 'gang'),
	(10, 'cartel', 0, 'gang'),
	(11, 'families', 0, 'gang'),
	(12, 'triads', 0, 'gang'),
	(13, 'teapot', 121623, 'boss');

-- Dumping structure for table origenv2qb.mdt_bolos
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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Dumping data for table origenv2qb.mdt_bolos: ~0 rows (approximately)

-- Dumping structure for table origenv2qb.mdt_bulletin
CREATE TABLE IF NOT EXISTS `mdt_bulletin` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `title` text NOT NULL,
  `desc` text NOT NULL,
  `author` varchar(50) NOT NULL,
  `time` varchar(20) NOT NULL,
  `jobtype` varchar(25) DEFAULT 'police',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Dumping data for table origenv2qb.mdt_bulletin: ~0 rows (approximately)

-- Dumping structure for table origenv2qb.mdt_clocking
CREATE TABLE IF NOT EXISTS `mdt_clocking` (
  `id` int(10) NOT NULL AUTO_INCREMENT,
  `user_id` varchar(50) NOT NULL DEFAULT '',
  `firstname` varchar(255) NOT NULL DEFAULT '',
  `lastname` varchar(255) NOT NULL DEFAULT '',
  `clock_in_time` varchar(255) NOT NULL DEFAULT '',
  `clock_out_time` varchar(50) DEFAULT NULL,
  `total_time` int(10) NOT NULL DEFAULT 0,
  PRIMARY KEY (`user_id`) USING BTREE,
  KEY `id` (`id`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=7 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Dumping data for table origenv2qb.mdt_clocking: ~0 rows (approximately)

-- Dumping structure for table origenv2qb.mdt_config
CREATE TABLE IF NOT EXISTS `mdt_config` (
  `citizenid` varchar(10) NOT NULL,
  `theme` int(11) NOT NULL,
  `sidebar` int(11) NOT NULL,
  UNIQUE KEY `citizenid` (`citizenid`) USING HASH
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

-- Dumping data for table origenv2qb.mdt_config: ~1 rows (approximately)
INSERT INTO `mdt_config` (`citizenid`, `theme`, `sidebar`) VALUES
	('ZEN90470', 1, 1);

-- Dumping structure for table origenv2qb.mdt_convictions
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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Dumping data for table origenv2qb.mdt_convictions: ~0 rows (approximately)

-- Dumping structure for table origenv2qb.mdt_data
CREATE TABLE IF NOT EXISTS `mdt_data` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `cid` varchar(20) NOT NULL,
  `information` mediumtext DEFAULT NULL,
  `tags` text NOT NULL,
  `gallery` text NOT NULL,
  `jobtype` varchar(25) DEFAULT 'police',
  `pfp` text DEFAULT NULL,
  `fingerprint` varchar(50) DEFAULT NULL,
  PRIMARY KEY (`cid`),
  KEY `id` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Dumping data for table origenv2qb.mdt_data: ~0 rows (approximately)

-- Dumping structure for table origenv2qb.mdt_evidences
CREATE TABLE IF NOT EXISTS `mdt_evidences` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `imgurl` text NOT NULL,
  `description` text NOT NULL,
  `type` text NOT NULL,
  `date` text NOT NULL,
  `createdby` text NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

-- Dumping data for table origenv2qb.mdt_evidences: ~0 rows (approximately)

-- Dumping structure for table origenv2qb.mdt_impound
CREATE TABLE IF NOT EXISTS `mdt_impound` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `vehicleid` int(11) NOT NULL,
  `linkedreport` int(11) NOT NULL,
  `fee` int(11) DEFAULT NULL,
  `time` varchar(255) NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Dumping data for table origenv2qb.mdt_impound: ~0 rows (approximately)

-- Dumping structure for table origenv2qb.mdt_incidents
CREATE TABLE IF NOT EXISTS `mdt_incidents` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `title` text NOT NULL,
  `description` text NOT NULL,
  `persons` text NOT NULL,
  `officers` text NOT NULL,
  `evidences` text NOT NULL,
  `vehicles` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL CHECK (json_valid(`vehicles`)),
  `criminals` text NOT NULL,
  `date` text NOT NULL,
  `createdby` text NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=7 DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

-- Dumping data for table origenv2qb.mdt_incidents: ~0 rows (approximately)
INSERT INTO `mdt_incidents` (`id`, `title`, `description`, `persons`, `officers`, `evidences`, `vehicles`, `criminals`, `date`, `createdby`) VALUES
	(6, 'Test', '123', '[{"citizenid":"ZEN90470","name":"Origen V2"}]', '[{"citizenid":"ZEN90470","name":"[1] Origen V2"}]', '[]', '[]', '[]', '2024-06-21T22:07:40.353Z', 'ZEN90470');

-- Dumping structure for table origenv2qb.mdt_logs
CREATE TABLE IF NOT EXISTS `mdt_logs` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `text` text NOT NULL,
  `time` varchar(20) DEFAULT NULL,
  `jobtype` varchar(25) DEFAULT 'police',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Dumping data for table origenv2qb.mdt_logs: ~0 rows (approximately)

-- Dumping structure for table origenv2qb.mdt_profiles
CREATE TABLE IF NOT EXISTS `mdt_profiles` (
  `citizenid` varchar(10) NOT NULL,
  `notes` text NOT NULL,
  `image` text NOT NULL,
  UNIQUE KEY `citizenid` (`citizenid`) USING HASH
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

-- Dumping data for table origenv2qb.mdt_profiles: ~0 rows (approximately)

-- Dumping structure for table origenv2qb.mdt_reports
CREATE TABLE IF NOT EXISTS `mdt_reports` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `type` text NOT NULL,
  `title` text NOT NULL,
  `description` text NOT NULL,
  `persons` text NOT NULL,
  `officers` text NOT NULL,
  `vehicles` text NOT NULL,
  `evidences` text NOT NULL,
  `date` text NOT NULL,
  `createdby` text NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

-- Dumping data for table origenv2qb.mdt_reports: ~0 rows (approximately)

-- Dumping structure for table origenv2qb.mdt_vehicleinfo
CREATE TABLE IF NOT EXISTS `mdt_vehicleinfo` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `plate` varchar(50) DEFAULT NULL,
  `information` text NOT NULL DEFAULT '',
  `stolen` tinyint(1) NOT NULL DEFAULT 0,
  `code5` tinyint(1) NOT NULL DEFAULT 0,
  `image` text NOT NULL DEFAULT '',
  `points` int(11) DEFAULT 0,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Dumping data for table origenv2qb.mdt_vehicleinfo: ~0 rows (approximately)

-- Dumping structure for table origenv2qb.mdt_vehicles
CREATE TABLE IF NOT EXISTS `mdt_vehicles` (
  `plate` varchar(10) NOT NULL,
  `image` text NOT NULL,
  `notes` text NOT NULL,
  UNIQUE KEY `plate` (`plate`) USING HASH
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

-- Dumping data for table origenv2qb.mdt_vehicles: ~0 rows (approximately)

-- Dumping structure for table origenv2qb.mdt_warrants
CREATE TABLE IF NOT EXISTS `mdt_warrants` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `incident` int(11) NOT NULL,
  `citizenid` text NOT NULL,
  `date` text NOT NULL,
  `approved` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

-- Dumping data for table origenv2qb.mdt_warrants: ~0 rows (approximately)

-- Dumping structure for table origenv2qb.mdt_weaponinfo
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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Dumping data for table origenv2qb.mdt_weaponinfo: ~0 rows (approximately)

-- Dumping structure for table origenv2qb.occasion_vehicles
CREATE TABLE IF NOT EXISTS `occasion_vehicles` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `seller` varchar(50) DEFAULT NULL,
  `price` int(11) DEFAULT NULL,
  `description` longtext DEFAULT NULL,
  `plate` varchar(50) DEFAULT NULL,
  `model` varchar(50) DEFAULT NULL,
  `mods` text DEFAULT NULL,
  `occasionid` varchar(50) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `occasionId` (`occasionid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Dumping data for table origenv2qb.occasion_vehicles: ~0 rows (approximately)

-- Dumping structure for table origenv2qb.origen_wallet
CREATE TABLE IF NOT EXISTS `origen_wallet` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `owner` varchar(46) DEFAULT NULL,
  `picture` longtext DEFAULT NULL,
  PRIMARY KEY (`id`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=6 DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

-- Dumping data for table origenv2qb.origen_wallet: ~0 rows (approximately)

-- Dumping structure for table origenv2qb.ox_doorlock
CREATE TABLE IF NOT EXISTS `ox_doorlock` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(50) NOT NULL,
  `data` longtext NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=111 DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

-- Dumping data for table origenv2qb.ox_doorlock: ~87 rows (approximately)
INSERT INTO `ox_doorlock` (`id`, `name`, `data`) VALUES
	(2, 'pdenterence', '{"doors":[{"model":-1547307588,"heading":270,"coords":{"x":434.74444580078127,"y":-980.7555541992188,"z":30.81530380249023}},{"model":-1547307588,"heading":90,"coords":{"x":434.74444580078127,"y":-983.078125,"z":30.81530380249023}}],"maxDistance":2,"groups":{"police":0},"coords":{"x":434.74444580078127,"y":-981.9168701171875,"z":30.81530380249023},"lockSound":"door_bolt","unlockSound":"door_bolt","state":0}'),
	(3, 'pdenterence2', '{"groups":{"police":0},"autolock":5,"doors":false,"state":1,"coords":{"x":441.1240539550781,"y":-977.60107421875,"z":30.82319259643554},"model":-1406685646,"heading":0,"maxDistance":2}'),
	(4, 'pdenterence1', '{"groups":{"police":0},"autolock":5,"doors":false,"state":1,"coords":{"x":441.12408447265627,"y":-986.2335205078125,"z":30.82319259643554},"model":-96679321,"heading":180,"maxDistance":2}'),
	(6, 'pdsideenterence1', '{"groups":{"police":0},"lockSound":"metallic_creak","unlockSound":"metallic_creak","autolock":5,"doors":[{"coords":{"x":440.73919677734377,"y":-998.7462158203125,"z":30.81530380249023},"heading":0,"model":-1547307588},{"coords":{"x":443.061767578125,"y":-998.7462158203125,"z":30.81530380249023},"heading":180,"model":-1547307588}],"state":1,"coords":{"x":441.9004821777344,"y":-998.7462158203125,"z":30.81530380249023},"maxDistance":2}'),
	(12, 'pdsideenterence2', '{"groups":{"police":0},"autolock":5,"doors":[{"coords":{"x":455.88616943359377,"y":-972.2542724609375,"z":30.8153076171875},"heading":0,"model":-1547307588},{"coords":{"x":458.208740234375,"y":-972.2542724609375,"z":30.8153076171875},"heading":180,"model":-1547307588}],"state":1,"coords":{"x":457.0474548339844,"y":-972.2542724609375,"z":30.8153076171875},"maxDistance":2}'),
	(13, 'pdgarage', '{"groups":{"police":0},"lockSound":"metal_locker","doorRate":0.8,"unlockSound":"metal_locker","autolock":5,"doors":false,"state":1,"coords":{"x":431.4118957519531,"y":-1000.771728515625,"z":26.69660949707031},"model":2130672747,"heading":0,"maxDistance":6.5}'),
	(14, 'pdgarage2', '{"doors":false,"model":2130672747,"heading":0,"coords":{"x":452.3005065917969,"y":-1000.771728515625,"z":26.69660949707031},"doorRate":0.9,"autolock":5,"unlockSound":"metal_locker","groups":{"police":0},"state":1,"maxDistance":4,"lockSound":"metal_locker"}'),
	(15, 'pdenterance', '{"autolock":10,"auto":true,"maxDistance":6,"groups":{"police":0},"heading":270,"coords":{"x":410.0257873535156,"y":-1028.3192138671876,"z":29.22019958496093},"model":-1635161509,"doors":false,"state":1}'),
	(16, 'pdent2', '{"autolock":10,"auto":true,"maxDistance":6,"groups":{"police":0},"heading":270,"coords":{"x":410.0257873535156,"y":-1020.15673828125,"z":29.2202205657959},"model":-1868050792,"doors":false,"state":1}'),
	(17, 'ems1', '{"autolock":3,"lockSound":"button_remote","heading":160,"groups":{"ambulance":0},"model":854291622,"doors":false,"coords":{"x":309.13372802734377,"y":-597.75146484375,"z":43.43391036987305},"state":1,"unlockSound":"button_remote","maxDistance":2}'),
	(18, 'ems2', '{"autolock":3,"lockSound":"button_remote","heading":250,"groups":{"ambulance":0},"model":854291622,"doors":false,"coords":{"x":313.4800720214844,"y":-595.4583129882813,"z":43.43391036987305},"state":1,"unlockSound":"button_remote","maxDistance":2}'),
	(19, 'ems3', '{"state":0,"groups":{"ambulance":0},"hideUi":true,"doors":[{"coords":{"x":318.48468017578127,"y":-579.2281494140625,"z":43.43391036987305},"heading":160,"model":-434783486},{"coords":{"x":316.0657043457031,"y":-578.3477172851563,"z":43.43391036987305},"heading":160,"model":-1700911976}],"coords":{"x":317.27520751953127,"y":-578.7879638671875,"z":43.43391036987305},"maxDistance":2}'),
	(20, 'ems5', '{"heading":70,"groups":{"ambulance":0},"model":854291622,"doors":false,"coords":{"x":303.9596252441406,"y":-572.5579223632813,"z":43.43391036987305},"state":1,"maxDistance":2}'),
	(21, 'ems6', '{"heading":340,"groups":{"ambulance":0},"model":854291622,"doors":false,"coords":{"x":307.1181945800781,"y":-569.5689697265625,"z":43.43391036987305},"state":1,"maxDistance":2}'),
	(22, 'ems7', '{"lockSound":"button_remote","state":1,"groups":{"ambulance":0},"doors":[{"coords":{"x":314.4241027832031,"y":-572.2215576171875,"z":43.43391036987305},"heading":340,"model":-1700911976},{"coords":{"x":312.005126953125,"y":-571.3411865234375,"z":43.43391036987305},"heading":340,"model":-434783486}],"coords":{"x":313.214599609375,"y":-571.7813720703125,"z":43.43391036987305},"unlockSound":"button_remote","maxDistance":2}'),
	(23, 'ems7', '{"lockSound":"button_remote","state":1,"groups":{"ambulance":0},"doors":[{"coords":{"x":320.26153564453127,"y":-574.3463134765625,"z":43.43391036987305},"heading":340,"model":-1700911976},{"coords":{"x":317.8425598144531,"y":-573.4658813476563,"z":43.43391036987305},"heading":340,"model":-434783486}],"coords":{"x":319.05206298828127,"y":-573.9061279296875,"z":43.43391036987305},"unlockSound":"button_remote","maxDistance":2}'),
	(24, 'ems9', '{"lockSound":"button_remote","state":1,"groups":{"ambulance":0},"doors":[{"coords":{"x":325.6565246582031,"y":-576.3099365234375,"z":43.43391036987305},"heading":340,"model":-1700911976},{"coords":{"x":323.237548828125,"y":-575.429443359375,"z":43.43391036987305},"heading":340,"model":-434783486}],"coords":{"x":324.447021484375,"y":-575.8696899414063,"z":43.43391036987305},"unlockSound":"button_remote","maxDistance":2}'),
	(25, 'ems10', '{"maxDistance":2,"coords":{"x":304.012451171875,"y":-581.8651123046875,"z":43.43391036987305},"hideUi":true,"groups":{"ambulance":0},"state":0,"doors":[{"coords":{"x":305.22186279296877,"y":-582.3056030273438,"z":43.43391036987305},"heading":340,"model":-1700911976},{"coords":{"x":302.8030700683594,"y":-581.424560546875,"z":43.43391036987305},"heading":340,"model":-434783486}]}'),
	(26, 'ems11', '{"state":1,"groups":{"police":0,"ambulance":0},"hideUi":true,"doors":[{"coords":{"x":324.23602294921877,"y":-589.2261962890625,"z":43.43391036987305},"heading":340,"model":-434783486},{"coords":{"x":326.6549987792969,"y":-590.1066284179688,"z":43.43391036987305},"heading":340,"model":-1700911976}],"coords":{"x":325.44549560546877,"y":-589.6663818359375,"z":43.43391036987305},"maxDistance":2}'),
	(27, 'emspd12wardc', '{"lockSound":"button_remote","state":1,"groups":{"police":0,"ambulance":0},"doors":[{"coords":{"x":349.3137512207031,"y":-586.3259887695313,"z":43.43391036987305},"heading":250,"model":-434783486},{"coords":{"x":348.4333190917969,"y":-588.7449951171875,"z":43.43391036987305},"heading":250,"model":-1700911976}],"coords":{"x":348.87353515625,"y":-587.5355224609375,"z":43.43391036987305},"unlockSound":"button_remote","maxDistance":2}'),
	(28, 'uwumain', '{"maxDistance":2,"groups":{"uwu":0},"hideUi":true,"state":1,"lockSound":"button_remote","coords":{"x":-581.014404296875,"y":-1069.627197265625,"z":22.48974800109863},"doors":[{"coords":{"x":-580.361083984375,"y":-1069.627197265625,"z":22.48974800109863},"model":-69331849,"heading":0},{"coords":{"x":-581.6677856445313,"y":-1069.627197265625,"z":22.48974800109863},"model":526179188,"heading":0}],"unlockSound":"button_remote"}'),
	(29, 'uwukitchenmain', '{"maxDistance":2,"groups":{"uwu":0},"hideUi":true,"model":-1283712428,"state":1,"lockSound":"button_remote","coords":{"x":-587.3400268554688,"y":-1051.8994140625,"z":22.41300582885742},"doors":false,"unlockSound":"button_remote","heading":90}'),
	(30, 'uwu1', '{"maxDistance":2,"groups":{"uwu":0},"hideUi":true,"model":-60871655,"state":1,"lockSound":"button_remote","coords":{"x":-590.1828002929688,"y":-1054.14794921875,"z":22.41300582885742},"doors":false,"unlockSound":"button_remote","heading":180}'),
	(31, 'uwu2', '{"maxDistance":2,"groups":{"uwu":0},"hideUi":true,"model":-60871655,"state":1,"lockSound":"button_remote","coords":{"x":-592.4738159179688,"y":-1056.09130859375,"z":22.41300582885742},"doors":false,"unlockSound":"button_remote","heading":0}'),
	(32, 'uwugarage', '{"maxDistance":2,"groups":{"uwu":0},"hideUi":true,"model":1099436502,"state":1,"lockSound":"metal_locker","coords":{"x":-600.8886108398438,"y":-1055.1314697265626,"z":22.71302795410156},"doors":false,"unlockSound":"metal_locker","heading":270}'),
	(33, 'uwugarage2', '{"maxDistance":2,"groups":{"uwu":0},"hideUi":true,"model":522844070,"state":1,"lockSound":"metallic_creak","coords":{"x":-600.9105834960938,"y":-1059.2176513671876,"z":21.72143173217773},"doors":false,"unlockSound":"metallic_creak","heading":270}'),
	(34, 'uwu3', '{"maxDistance":2,"groups":{"uwu":0},"hideUi":true,"model":2089009131,"state":1,"lockSound":"button_remote","coords":{"x":-594.4122924804688,"y":-1049.7686767578126,"z":22.49712753295898},"doors":false,"unlockSound":"button_remote","heading":90}'),
	(35, 'uwuupperfloor', '{"maxDistance":2,"groups":{"uwu":0},"hideUi":true,"model":2089009131,"state":1,"lockSound":"button_remote","coords":{"x":-571.7926635742188,"y":-1057.388427734375,"z":26.76796531677246},"doors":false,"unlockSound":"button_remote","heading":0}'),
	(36, 'uwuupperfloor1', '{"maxDistance":2,"groups":{"uwu":0},"hideUi":true,"model":2089009131,"state":1,"lockSound":"button_remote","coords":{"x":-575.0108642578125,"y":-1062.3807373046876,"z":26.76796531677246},"doors":false,"unlockSound":"button_remote","heading":270}'),
	(37, 'uwuupperfloor2', '{"maxDistance":2,"groups":{"uwu":0},"hideUi":true,"model":2089009131,"state":1,"lockSound":"button_remote","coords":{"x":-575.0128173828125,"y":-1063.7833251953126,"z":26.76796531677246},"doors":false,"unlockSound":"button_remote","heading":90}'),
	(47, 'uwustash', '{"coords":{"x":-591.7698974609375,"y":-1066.9739990234376,"z":22.53749465942382},"unlockSound":"metal_locker","hideUi":true,"groups":{"uwu":0},"doors":false,"lockSound":"metal_locker","state":1,"maxDistance":2,"model":-562476388,"heading":270}'),
	(48, 'bsmaindoor', '{"coords":{"x":-1181.4556884765626,"y":-886.404052734375,"z":14.09526920318603},"unlockSound":"button_remote","hideUi":true,"groups":{"burgershot":0},"doors":[{"coords":{"x":-1180.728515625,"y":-887.4773559570313,"z":14.09526920318603},"heading":124,"model":-1890974902},{"coords":{"x":-1182.182861328125,"y":-885.330810546875,"z":14.09526920318603},"heading":304,"model":1143532813}],"lockSound":"button_remote","state":1,"maxDistance":2}'),
	(49, 'bsbackdoor', '{"coords":{"x":-1197.09912109375,"y":-903.9393920898438,"z":14.03526592254638},"unlockSound":"button_remote","hideUi":true,"groups":{"burgershot":0},"doors":false,"lockSound":"button_remote","state":1,"maxDistance":2,"model":1465287574,"heading":214}'),
	(50, 'bskitchenbackdoor', '{"coords":{"x":-1200.7210693359376,"y":-900.771728515625,"z":13.90556144714355},"unlockSound":"button_remote","hideUi":true,"groups":{"burgershot":0},"doors":false,"lockSound":"button_remote","state":1,"maxDistance":2,"model":2010236044,"heading":214}'),
	(51, 'bskitchenmain', '{"coords":{"x":-1188.0657958984376,"y":-896.6784057617188,"z":13.90556144714355},"unlockSound":"button_remote","hideUi":true,"groups":{"burgershot":0},"doors":false,"lockSound":"button_remote","state":1,"maxDistance":2,"model":2010236044,"heading":304}'),
	(52, 'pdground2', '{"groups":{"police":0},"lockSound":"door_bolt","unlockSound":"door_bolt","autolock":5,"doors":[{"coords":{"x":467.522216796875,"y":-1000.543701171875,"z":26.40548324584961},"heading":0,"model":-288803980},{"coords":{"x":469.9273681640625,"y":-1000.543701171875,"z":26.40548324584961},"heading":180,"model":-288803980}],"state":1,"coords":{"x":468.72479248046877,"y":-1000.543701171875,"z":26.40548324584961},"maxDistance":2}'),
	(53, 'ground1', '{"groups":{"police":0},"lockSound":"door_bolt","unlockSound":"door_bolt","autolock":5,"doors":[{"coords":{"x":471.36785888671877,"y":-1007.7933959960938,"z":26.40548324584961},"heading":270,"model":149284793},{"coords":{"x":471.3758239746094,"y":-1010.1978759765625,"z":26.40548324584961},"heading":90,"model":149284793}],"state":1,"coords":{"x":471.371826171875,"y":-1008.99560546875,"z":26.40548324584961},"maxDistance":2}'),
	(54, 'pdcellsmain', '{"groups":{"police":0},"lockSound":"metallic_creak","unlockSound":"metallic_creak","autolock":5,"doors":false,"state":1,"coords":{"x":476.64471435546877,"y":-1008.2840576171875,"z":26.48005485534668},"model":-53345114,"heading":270,"maxDistance":2}'),
	(55, 'cell1', '{"heading":0,"groups":{"police":0},"unlockSound":"metallic_creak","doors":false,"model":-53345114,"maxDistance":2,"state":1,"coords":{"x":477.91259765625,"y":-1012.1886596679688,"z":26.48005485534668},"lockSound":"metallic_creak"}'),
	(56, 'cell3', '{"heading":0,"groups":{"police":0},"unlockSound":"metallic_creak","doors":false,"model":-53345114,"maxDistance":2,"state":1,"coords":{"x":480.9128112792969,"y":-1012.1886596679688,"z":26.48005485534668},"lockSound":"metallic_creak"}'),
	(57, 'cell4', '{"heading":0,"groups":{"police":0},"unlockSound":"metallic_creak","doors":false,"model":-53345114,"maxDistance":2,"state":1,"coords":{"x":483.9127197265625,"y":-1012.1886596679688,"z":26.48005485534668},"lockSound":"metallic_creak"}'),
	(58, 'cell5', '{"heading":0,"groups":{"police":0},"unlockSound":"metallic_creak","doors":false,"model":-53345114,"maxDistance":2,"state":1,"coords":{"x":486.9131164550781,"y":-1012.1886596679688,"z":26.48005485534668},"lockSound":"metallic_creak"}'),
	(59, 'cellbig', '{"heading":180,"groups":{"police":0},"unlockSound":"metallic_creak","doors":false,"model":-53345114,"maxDistance":2,"state":1,"coords":{"x":484.1764221191406,"y":-1007.734375,"z":26.48005485534668},"lockSound":"metallic_creak"}'),
	(60, 'cellentinner', '{"groups":{"police":0},"lockSound":"metallic_creak","unlockSound":"metallic_creak","autolock":5,"doors":false,"state":1,"coords":{"x":481.5995788574219,"y":-1004.1484375,"z":26.48005485534668},"model":-53345114,"heading":180,"maxDistance":2}'),
	(61, 'pdint2', '{"groups":{"police":0},"lockSound":"metallic_creak","unlockSound":"metallic_creak","autolock":5,"doors":false,"state":1,"coords":{"x":482.67022705078127,"y":-996.33251953125,"z":26.40548324584961},"model":-1406685646,"heading":270,"maxDistance":2}'),
	(62, 'pdob2', '{"groups":{"police":0},"lockSound":"metallic_creak","unlockSound":"metallic_creak","autolock":5,"doors":false,"state":1,"coords":{"x":482.669921875,"y":-992.9031982421875,"z":26.40548324584961},"model":-1406685646,"heading":270,"maxDistance":2}'),
	(63, 'pdint1', '{"groups":{"police":0},"lockSound":"metallic_creak","unlockSound":"metallic_creak","autolock":5,"doors":false,"state":1,"coords":{"x":482.6701354980469,"y":-988.1831665039063,"z":26.40548324584961},"model":-1406685646,"heading":270,"maxDistance":2}'),
	(64, 'pdob1', '{"groups":{"police":0},"lockSound":"metallic_creak","unlockSound":"metallic_creak","autolock":5,"doors":false,"state":1,"coords":{"x":482.66943359375,"y":-984.5908203125,"z":26.40548324584961},"model":-1406685646,"heading":270,"maxDistance":2}'),
	(65, 'pdevidence', '{"groups":{"police":0},"lockSound":"button_remote","unlockSound":"button_remote","autolock":5,"doors":false,"state":1,"coords":{"x":475.4071960449219,"y":-990.0584106445313,"z":26.40548324584961},"model":-692649124,"heading":135,"maxDistance":2}'),
	(67, 'pdpark2', '{"groups":{"police":0},"lockSound":"metallic_creak","unlockSound":"metallic_creak","autolock":5,"doors":false,"state":1,"coords":{"x":464.1568603515625,"y":-975.2672119140625,"z":26.3707046508789},"model":1830360419,"heading":270,"maxDistance":2}'),
	(68, 'pdpark1', '{"groups":{"police":0},"lockSound":"metallic_creak","unlockSound":"metallic_creak","autolock":5,"doors":false,"state":1,"coords":{"x":464.1579284667969,"y":-996.90771484375,"z":26.3707046508789},"model":1830360419,"heading":90,"maxDistance":2}'),
	(70, 'doj', '{"coords":{"x":-545.5143432617188,"y":-203.3874969482422,"z":38.62826919555664},"state":0,"groups":{"lawyer":0},"doors":[{"model":2537604,"coords":{"x":-544.52197265625,"y":-202.8148956298828,"z":38.62826919555664},"heading":30},{"model":2537604,"coords":{"x":-546.5067138671875,"y":-203.96009826660157,"z":38.62826919555664},"heading":210}],"maxDistance":2}'),
	(71, 'lscustomsmain', '{"doorRate":0.7,"model":-1958316735,"state":1,"unlockSound":"button_remote","coords":{"x":871.2015380859375,"y":-2112.940673828125,"z":31.75130844116211},"maxDistance":5,"groups":{"mechanic":0},"doors":false,"lockSound":"button_remote","heading":265}'),
	(72, 'lscustoms2', '{"doorRate":0.7,"model":-1958316735,"state":1,"unlockSound":"button_remote","coords":{"x":908.8870849609375,"y":-2097.85205078125,"z":31.74398803710937},"maxDistance":5,"groups":{"mechanic":0},"doors":false,"lockSound":"button_remote","heading":175}'),
	(73, 'lscustoms3main', '{"doors":false,"heading":175,"unlockSound":"door_bolt","model":-88942360,"lockSound":"door_bolt","state":1,"groups":{"mechanic":0},"coords":{"x":896.8566284179688,"y":-2104.47119140625,"z":35.03548049926758},"maxDistance":2}'),
	(74, 'cardealermain', '{"doors":[{"coords":{"x":110.84381103515625,"y":-151.0354766845703,"z":55.02302551269531},"model":1225835816,"heading":295},{"coords":{"x":111.8766860961914,"y":-153.25048828125,"z":55.03302383422851},"model":1225835816,"heading":115}],"state":1,"maxDistance":2,"coords":{"x":111.36024475097656,"y":-152.14297485351563,"z":55.02802276611328},"lockSound":"button_remote","unlockSound":"button_remote","groups":{"cardealer":0}}'),
	(75, 'cardealerback', '{"doors":false,"state":1,"maxDistance":5,"model":-243440858,"coords":{"x":117.86335754394531,"y":-135.81602478027345,"z":53.83846664428711},"lockSound":"button_remote","unlockSound":"button_remote","heading":160,"groups":{"cardealer":0}}'),
	(76, 'pdmoffice', '{"model":788691675,"state":1,"unlockSound":"door_bolt","autolock":5,"coords":{"x":146.06089782714845,"y":-148.10659790039063,"z":55.01000213623047},"maxDistance":2,"hideUi":true,"groups":{"cardealer":0},"doors":false,"lockSound":"door_bolt","heading":340}'),
	(79, 'pdarmoury', '{"groups":{"police":0},"autolock":5,"doors":[{"coords":{"x":469.44061279296877,"y":-985.0313110351563,"z":30.82319259643554},"heading":270,"model":-288803980},{"coords":{"x":469.44061279296877,"y":-987.4376831054688,"z":30.82319259643554},"heading":90,"model":-288803980}],"state":1,"coords":{"x":469.44061279296877,"y":-986.2344970703125,"z":30.82319259643554},"maxDistance":2}'),
	(80, 'pdroof', '{"groups":{"police":0},"autolock":5,"doors":false,"state":1,"coords":{"x":464.3085632324219,"y":-984.5284423828125,"z":43.771240234375},"model":-692649124,"heading":90,"maxDistance":2}'),
	(81, 'ems_garage2', '{"groups":{"ambulance":0},"doorRate":0.7,"autolock":5,"doors":false,"state":1,"coords":{"x":337.2776794433594,"y":-564.4320068359375,"z":29.77529144287109},"model":-820650556,"heading":160,"maxDistance":4}'),
	(82, 'emsgarage1', '{"doorRate":0.7,"auto":true,"autolock":5,"doors":false,"state":1,"coords":{"x":330.1349182128906,"y":-561.8331298828125,"z":29.77529144287109},"model":-820650556,"heading":160,"maxDistance":4}'),
	(84, 'prisonenterence', '{"groups":{"police":0},"autolock":5,"doors":false,"state":1,"coords":{"x":1845.3358154296876,"y":2585.34765625,"z":46.08550262451172},"model":705715602,"heading":90,"maxDistance":2}'),
	(85, 'prisons1', '{"groups":{"police":0},"autolock":5,"doors":false,"state":1,"coords":{"x":1837.6337890625,"y":2576.99169921875,"z":46.03859710693359},"model":2024969025,"heading":0,"maxDistance":2}'),
	(86, 'prisons2', '{"groups":{"police":0},"autolock":5,"doors":false,"state":1,"coords":{"x":1844.40380859375,"y":2576.9970703125,"z":46.03560256958008},"model":2024969025,"heading":0,"maxDistance":2}'),
	(87, 'prisons3', '{"groups":{"police":0},"autolock":5,"doors":false,"state":1,"coords":{"x":1835.527587890625,"y":2587.440185546875,"z":46.03711700439453},"model":-684929024,"heading":90,"maxDistance":2}'),
	(88, 'prisons4', '{"groups":{"police":0},"autolock":5,"doors":false,"state":1,"coords":{"x":1797.760986328125,"y":2596.56494140625,"z":46.38731002807617},"model":-1156020871,"heading":180,"maxDistance":2}'),
	(89, 'prisons5', '{"auto":true,"heading":90,"doors":false,"maxDistance":7.5,"autolock":15,"coords":{"x":1844.97802734375,"y":2608.4267578125,"z":44.63977813720703},"model":741314661,"groups":{"police":0},"state":1}'),
	(90, 'prisons6', '{"auto":true,"heading":90,"doors":false,"maxDistance":7.5,"autolock":15,"coords":{"x":1818.52294921875,"y":2608.4267578125,"z":44.61100006103515},"model":741314661,"groups":{"police":0},"state":1}'),
	(91, 'prisons7', '{"groups":{"police":0},"auto":true,"autolock":5,"doors":false,"state":1,"coords":{"x":1799.6080322265626,"y":2616.97509765625,"z":44.6032485961914},"model":741314661,"heading":180,"maxDistance":7.5}'),
	(92, 'prisons7', '{"groups":{"police":0},"auto":true,"autolock":5,"doors":[{"coords":{"x":1808.991943359375,"y":2474.544921875,"z":44.48077011108398},"heading":71,"model":741314661},{"coords":{"x":1813.7490234375,"y":2488.906982421875,"z":44.46368026733398},"heading":252,"model":741314661}],"state":1,"coords":{"x":1811.3704833984376,"y":2481.72607421875,"z":44.47222518920898},"maxDistance":7.5}'),
	(93, 'prisons8', '{"groups":{"police":0},"auto":true,"autolock":5,"doors":[{"coords":{"x":1762.5419921875,"y":2426.507080078125,"z":44.43787002563476},"heading":206,"model":741314661},{"coords":{"x":1749.1419677734376,"y":2419.81201171875,"z":44.4251708984375},"heading":27,"model":741314661}],"state":1,"coords":{"x":1755.842041015625,"y":2423.15966796875,"z":44.4315185546875},"maxDistance":7.5}'),
	(94, 'prisons9', '{"groups":{"police":0},"auto":true,"autolock":5,"doors":[{"coords":{"x":1667.6689453125,"y":2407.64794921875,"z":44.42879104614258},"heading":173,"model":741314661},{"coords":{"x":1652.9840087890626,"y":2409.571044921875,"z":44.44308090209961},"heading":353,"model":741314661}],"state":1,"coords":{"x":1660.326416015625,"y":2408.609375,"z":44.43593597412109},"maxDistance":7.5}'),
	(95, 'prisons10', '{"groups":{"police":0},"auto":true,"autolock":5,"doors":[{"coords":{"x":1550.930419921875,"y":2482.743408203125,"z":44.39528656005859},"heading":298,"model":741314661},{"coords":{"x":1558.22119140625,"y":2469.34912109375,"z":44.39528656005859},"heading":118,"model":741314661}],"state":1,"coords":{"x":1554.5758056640626,"y":2476.04638671875,"z":44.39528656005859},"maxDistance":7.5}'),
	(96, 'prisons11', '{"groups":{"police":0},"auto":true,"autolock":5,"doors":[{"coords":{"x":1547.7061767578126,"y":2591.2822265625,"z":44.50946807861328},"heading":267,"model":741314661},{"coords":{"x":1546.9833984375,"y":2576.129638671875,"z":44.39032745361328},"heading":87,"model":741314661}],"state":1,"coords":{"x":1547.3447265625,"y":2583.7060546875,"z":44.44989776611328},"maxDistance":7.5}'),
	(97, 'prisons12', '{"groups":{"police":0},"auto":true,"autolock":5,"doors":[{"coords":{"x":1584.6529541015626,"y":2679.7490234375,"z":44.50947189331055},"heading":234,"model":741314661},{"coords":{"x":1575.719482421875,"y":2667.15185546875,"z":44.50946807861328},"heading":55,"model":741314661}],"state":1,"coords":{"x":1580.186279296875,"y":2673.450439453125,"z":44.50946807861328},"maxDistance":7.5}'),
	(98, 'prisons13', '{"groups":{"police":0},"auto":true,"autolock":5,"doors":[{"coords":{"x":1662.010986328125,"y":2748.702880859375,"z":44.44668960571289},"heading":207,"model":741314661},{"coords":{"x":1648.4110107421876,"y":2741.66796875,"z":44.44668960571289},"heading":27,"model":741314661}],"state":1,"coords":{"x":1655.2109375,"y":2745.185546875,"z":44.44668960571289},"maxDistance":7.5}'),
	(99, 'prisons14', '{"groups":{"police":0},"auto":true,"autolock":5,"doors":[{"coords":{"x":1776.7010498046876,"y":2747.14794921875,"z":44.44668960571289},"heading":160,"model":741314661},{"coords":{"x":1762.196044921875,"y":2752.489013671875,"z":44.44668960571289},"heading":340,"model":741314661}],"state":1,"coords":{"x":1769.448486328125,"y":2749.818359375,"z":44.44668960571289},"maxDistance":7.5}'),
	(100, 'prisons15', '{"groups":{"police":0},"auto":true,"autolock":5,"doors":[{"coords":{"x":1835.2850341796876,"y":2689.10400390625,"z":44.44670104980469},"heading":110,"model":741314661},{"coords":{"x":1830.134033203125,"y":2703.4990234375,"z":44.44670104980469},"heading":289,"model":741314661}],"state":1,"coords":{"x":1832.70947265625,"y":2696.301513671875,"z":44.44670104980469},"maxDistance":7.5}'),
	(101, 'bankkk', '{"state":0,"doors":[{"heading":160,"coords":{"x":313.8901672363281,"y":-275.7320861816406,"z":53.16696166992187},"model":122382010},{"heading":340,"coords":{"x":316.36578369140627,"y":-276.6327209472656,"z":53.16696548461914},"model":1451558188}],"doorRate":11,"coords":{"x":315.12799072265627,"y":-276.1824035644531,"z":53.16696166992187},"maxDistance":2,"hideUi":true}'),
	(102, 'EMSPILLBOXMAIN', '{"coords":{"x":299.62933349609377,"y":-584.8292846679688,"z":42.28400802612305},"doorRate":11,"hideUi":true,"maxDistance":2,"doors":[{"heading":250,"model":-487908756,"coords":{"x":299.22784423828127,"y":-585.9323120117188,"z":42.28400802612305}},{"heading":250,"model":661758796,"coords":{"x":300.0307922363281,"y":-583.7262573242188,"z":42.28400802612305}}],"state":0}'),
	(103, 'legionbank', '{"state":0,"hideUi":true,"doors":[{"model":122382010,"heading":160,"coords":{"x":149.5612030029297,"y":-1037.3663330078126,"z":28.37025070190429}},{"model":1451558188,"heading":340,"coords":{"x":152.0364990234375,"y":-1038.267822265625,"z":28.37025260925293}}],"maxDistance":2,"coords":{"x":150.79885864257813,"y":-1037.817138671875,"z":28.37025070190429},"doorRate":11}'),
	(104, 'bankkkkk2', '{"state":0,"hideUi":true,"doors":[{"model":122382010,"heading":207,"coords":{"x":-1215.333740234375,"y":-328.666259765625,"z":36.78320693969726}},{"model":1451558188,"heading":27,"coords":{"x":-1212.98681640625,"y":-327.47003173828127,"z":36.78321075439453}}],"maxDistance":2,"coords":{"x":-1214.1602783203126,"y":-328.0681457519531,"z":36.78321075439453},"doorRate":11}'),
	(105, 'bankjod1', '{"state":0,"hideUi":true,"doors":[{"model":122382010,"heading":161,"coords":{"x":-351.325927734375,"y":-46.5489387512207,"z":48.03874969482422}},{"model":1451558188,"heading":341,"coords":{"x":-348.8350524902344,"y":-47.40649795532226,"z":48.03875350952148}}],"maxDistance":2,"coords":{"x":-350.08050537109377,"y":-46.97771835327148,"z":48.03874969482422},"doorRate":11}'),
	(106, 'bankjod2', '{"state":0,"hideUi":true,"doors":[{"model":122382010,"heading":268,"coords":{"x":-2965.671142578125,"y":481.60565185546877,"z":14.69926261901855}},{"model":1451558188,"heading":88,"coords":{"x":-2965.564697265625,"y":484.23785400390627,"z":14.69926452636718}}],"maxDistance":2,"coords":{"x":-2965.617919921875,"y":482.9217529296875,"z":14.69926357269287},"doorRate":11}'),
	(107, 'vec3(488.894806, -1017.211975, 27.149349)', '{"autolock":10,"auto":true,"maxDistance":6,"groups":{"police":0},"heading":90,"coords":{"x":488.8948059082031,"y":-1017.2119750976563,"z":27.14934921264648},"model":-1603817716,"doors":false,"doorRate":0.7,"state":1}'),
	(109, 'pdbackdoor2', '{"autolock":5,"maxDistance":2,"groups":{"police":0},"coords":{"x":468.5714416503906,"y":-1014.406005859375,"z":26.48381614685058},"doors":[{"model":-692649124,"heading":180,"coords":{"x":469.7742614746094,"y":-1014.406005859375,"z":26.48381614685058}},{"model":-692649124,"heading":0,"coords":{"x":467.3686218261719,"y":-1014.406005859375,"z":26.48381614685058}}],"state":1}'),
	(110, 'newplayer', '{"coords":{"x":-1002.146728515625,"y":-478.064208984375,"z":50.1166763305664},"maxDistance":2,"doors":false,"heading":299,"autolock":1,"state":1,"model":-2030220382,"hideUi":true}');

-- Dumping structure for table origenv2qb.pa_vehicleshop_showroom_vehicles
CREATE TABLE IF NOT EXISTS `pa_vehicleshop_showroom_vehicles` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `dealershipId` int(11) DEFAULT NULL,
  `data` longtext NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

-- Dumping data for table origenv2qb.pa_vehicleshop_showroom_vehicles: ~1 rows (approximately)
INSERT INTO `pa_vehicleshop_showroom_vehicles` (`id`, `dealershipId`, `data`) VALUES
	(3, 1, '[{"vehicleModel":"sultan3","coords":{"x":-50.66999816894531,"y":-1116.43994140625,"z":25.96999931335449,"w":2.25999999046325},"spotId":1,"vehicle":5566210},{"vehicleModel":"rhinehart","coords":{"x":-53.56000137329101,"y":-1116.8399658203126,"z":25.79000091552734,"w":3.35999989509582},"spotId":2,"vehicle":4853250},{"vehicleModel":"jubilee","coords":{"x":-56.29999923706055,"y":-1116.969970703125,"z":25.65999984741211,"w":1.12999999523162},"spotId":3,"vehicle":4853506},{"vehicleModel":"sultanrs","coords":{"x":-59.18000030517578,"y":-1116.8900146484376,"z":26.17000007629394,"w":1.44000005722045},"spotId":4,"vehicle":5568002},{"vehicleModel":"chino","coords":{"x":-61.83000183105469,"y":-1117.06005859375,"z":25.84000015258789,"w":2.23000001907348},"spotId":5,"vehicle":4854018}]');

-- Dumping structure for table origenv2qb.pa_vehicleshop_stocks
CREATE TABLE IF NOT EXISTS `pa_vehicleshop_stocks` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `model` varchar(50) NOT NULL DEFAULT '0',
  `stock` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

-- Dumping data for table origenv2qb.pa_vehicleshop_stocks: ~0 rows (approximately)

-- Dumping structure for table origenv2qb.phone_accounts
CREATE TABLE IF NOT EXISTS `phone_accounts` (
  `app` varchar(50) NOT NULL,
  `id` varchar(80) NOT NULL,
  `name` varchar(50) NOT NULL,
  `password` varchar(50) NOT NULL,
  `birthdate` varchar(50) NOT NULL,
  `gender` varchar(50) NOT NULL,
  `interested` text NOT NULL,
  `avatar` text NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Dumping data for table origenv2qb.phone_accounts: ~0 rows (approximately)

-- Dumping structure for table origenv2qb.phone_alertjobs
CREATE TABLE IF NOT EXISTS `phone_alertjobs` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `job` varchar(255) NOT NULL,
  `alerts` text DEFAULT NULL,
  `date` timestamp NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `job` (`job`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Dumping data for table origenv2qb.phone_alertjobs: ~0 rows (approximately)

-- Dumping structure for table origenv2qb.phone_chatrooms
CREATE TABLE IF NOT EXISTS `phone_chatrooms` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `room_code` varchar(10) NOT NULL,
  `room_name` varchar(15) NOT NULL,
  `room_owner_id` varchar(20) DEFAULT NULL,
  `room_owner_name` varchar(60) DEFAULT NULL,
  `room_members` text DEFAULT '{}',
  `room_pin` varchar(50) DEFAULT NULL,
  `unpaid_balance` decimal(10,2) DEFAULT 0.00,
  `is_pinned` tinyint(1) DEFAULT 0,
  `created` datetime DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `room_code` (`room_code`)
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

-- Dumping data for table origenv2qb.phone_chatrooms: ~0 rows (approximately)

-- Dumping structure for table origenv2qb.phone_chatroom_messages
CREATE TABLE IF NOT EXISTS `phone_chatroom_messages` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `room_id` int(10) unsigned DEFAULT NULL,
  `member_id` varchar(20) DEFAULT NULL,
  `member_name` varchar(50) DEFAULT NULL,
  `message` text NOT NULL,
  `is_pinned` tinyint(1) DEFAULT 0,
  `created` datetime DEFAULT current_timestamp(),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

-- Dumping data for table origenv2qb.phone_chatroom_messages: ~0 rows (approximately)

-- Dumping structure for table origenv2qb.phone_chats
CREATE TABLE IF NOT EXISTS `phone_chats` (
  `app` varchar(50) NOT NULL,
  `author` varchar(50) NOT NULL,
  `number` varchar(50) NOT NULL,
  `created` varchar(50) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Dumping data for table origenv2qb.phone_chats: ~0 rows (approximately)

-- Dumping structure for table origenv2qb.phone_gallery
CREATE TABLE IF NOT EXISTS `phone_gallery` (
  `citizenid` varchar(255) NOT NULL,
  `image` varchar(255) NOT NULL,
  `date` timestamp NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Dumping data for table origenv2qb.phone_gallery: ~0 rows (approximately)

-- Dumping structure for table origenv2qb.phone_invoices
CREATE TABLE IF NOT EXISTS `phone_invoices` (
  `id` int(10) NOT NULL AUTO_INCREMENT,
  `citizenid` varchar(50) DEFAULT NULL,
  `amount` int(11) NOT NULL DEFAULT 0,
  `society` tinytext DEFAULT NULL,
  `sender` varchar(50) DEFAULT NULL,
  `sendercitizenid` varchar(50) DEFAULT NULL,
  `time` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `citizenid` (`citizenid`)
) ENGINE=InnoDB AUTO_INCREMENT=42 DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

-- Dumping data for table origenv2qb.phone_invoices: ~0 rows (approximately)

-- Dumping structure for table origenv2qb.phone_messages
CREATE TABLE IF NOT EXISTS `phone_messages` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `citizenid` varchar(50) DEFAULT NULL,
  `number` varchar(50) DEFAULT NULL,
  `messages` text DEFAULT NULL,
  `time` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `citizenid` (`citizenid`),
  KEY `number` (`number`)
) ENGINE=InnoDB AUTO_INCREMENT=11 DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

-- Dumping data for table origenv2qb.phone_messages: ~0 rows (approximately)

-- Dumping structure for table origenv2qb.phone_note
CREATE TABLE IF NOT EXISTS `phone_note` (
  `id` int(10) NOT NULL AUTO_INCREMENT,
  `citizenid` varchar(50) DEFAULT NULL,
  `title` text DEFAULT NULL,
  `text` text DEFAULT NULL,
  `lastupdate` varchar(50) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `citizenid` (`citizenid`)
) ENGINE=InnoDB AUTO_INCREMENT=56 DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

-- Dumping data for table origenv2qb.phone_note: ~0 rows (approximately)

-- Dumping structure for table origenv2qb.phone_notifies
CREATE TABLE IF NOT EXISTS `phone_notifies` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `phone` varchar(50) NOT NULL,
  `msg_content` text NOT NULL,
  `msg_head` varchar(50) NOT NULL DEFAULT '',
  `app_name` text NOT NULL,
  `msg_time` varchar(50) NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=64 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Dumping data for table origenv2qb.phone_notifies: ~0 rows (approximately)

-- Dumping structure for table origenv2qb.phone_tweets
CREATE TABLE IF NOT EXISTS `phone_tweets` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `citizenid` varchar(50) DEFAULT NULL,
  `firstName` varchar(25) DEFAULT NULL,
  `lastName` varchar(25) DEFAULT NULL,
  `type` varchar(25) DEFAULT NULL,
  `message` text DEFAULT NULL,
  `url` text DEFAULT NULL,
  `tweetId` varchar(25) NOT NULL,
  `date` datetime DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `citizenid` (`citizenid`)
) ENGINE=InnoDB AUTO_INCREMENT=289 DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

-- Dumping data for table origenv2qb.phone_tweets: ~0 rows (approximately)

-- Dumping structure for table origenv2qb.players
CREATE TABLE IF NOT EXISTS `players` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `citizenid` varchar(50) NOT NULL,
  `cid` int(11) DEFAULT NULL,
  `license` varchar(255) NOT NULL,
  `name` varchar(255) NOT NULL,
  `money` text NOT NULL,
  `charinfo` text DEFAULT NULL,
  `job` text NOT NULL,
  `gang` text DEFAULT NULL,
  `position` text NOT NULL,
  `metadata` text NOT NULL,
  `inventory` longtext DEFAULT NULL,
  `last_updated` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `playtime` int(11) DEFAULT 0,
  `apps` text DEFAULT NULL,
  `widget` text DEFAULT NULL,
  `bt` text DEFAULT NULL,
  `cryptocurrency` longtext DEFAULT NULL,
  `cryptocurrencytransfers` text DEFAULT NULL,
  `crafting_level` tinyint(4) NOT NULL DEFAULT 1,
  `crafting_xp` smallint(6) NOT NULL DEFAULT 0,
  `level` int(11) NOT NULL DEFAULT 1,
  `lvlpro` int(11) NOT NULL DEFAULT 0,
  `skills` longtext DEFAULT NULL,
  `frkn_fuelstation_control` int(11) NOT NULL DEFAULT 0,
  `phone_number` varchar(20) DEFAULT NULL,
  `twitteraccount` varchar(50) DEFAULT NULL,
  `settings` longtext DEFAULT NULL,
  `calls` longtext DEFAULT NULL,
  `notes` longtext DEFAULT NULL,
  `photos` longtext DEFAULT NULL,
  `darkchatuser` mediumtext DEFAULT NULL,
  `mailaccount` varchar(50) DEFAULT NULL,
  `iban` varchar(50) DEFAULT NULL,
  `phone` varchar(45) DEFAULT NULL,
  `tattoos` longtext DEFAULT NULL,
  `priority` longtext DEFAULT NULL,
  `hackerMenu` longtext NOT NULL DEFAULT '{"xp":100,"LspdActivePersonel":0,"PhoneCheck":0,"PhonefromName":0,"CctvCamera":0,"AnonimTweet":0,"CarLock":0,"LocationCheck":0,"BankHack":0,"SendAllDM":0}',
  PRIMARY KEY (`citizenid`),
  KEY `id` (`id`),
  KEY `last_updated` (`last_updated`),
  KEY `license` (`license`)
) ENGINE=InnoDB AUTO_INCREMENT=208226 DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

-- Dumping data for table origenv2qb.players: ~1 rows (approximately)
INSERT INTO `players` (`id`, `citizenid`, `cid`, `license`, `name`, `money`, `charinfo`, `job`, `gang`, `position`, `metadata`, `inventory`, `last_updated`, `playtime`, `apps`, `widget`, `bt`, `cryptocurrency`, `cryptocurrencytransfers`, `crafting_level`, `crafting_xp`, `level`, `lvlpro`, `skills`, `frkn_fuelstation_control`, `phone_number`, `twitteraccount`, `settings`, `calls`, `notes`, `photos`, `darkchatuser`, `mailaccount`, `iban`, `phone`, `tattoos`, `priority`, `hackerMenu`) VALUES
	(208050, 'ZEN90470', 1, 'license:407894f5ace9e794698132ea12dd8807b5ae71bc', 'Elixir', '{"bank":123123123168856,"crypto":1.9125,"cash":444}', '{"nationality":"By ElixirFW","cid":"1","account":"US03QBCore2891459053","backstory":"placeholder backstory","lastname":"V2","firstname":"Origen","gender":0,"birthdate":"2005-06-08","phone":"3173038217"}', '{"label":"EMS","payment":75,"onduty":true,"type":"ems","name":"ambulance","isboss":false,"grade":{"level":1,"name":"Paramedic"}}', '{"label":"No Gang Affiliaton","name":"none","isboss":false,"grade":{"level":0,"name":"none"}}', '{"x":419.19561767578127,"y":-816.09228515625,"z":29.21240234375}', '{"dealerrep":0,"status":[],"jailitems":[],"licences":{"business":false,"weapon":false,"driver":true},"attachmentcraftingrep":0,"jobrep":{"trucker":0,"hotdog":4,"taxi":0,"tow":1},"criminalrecord":{"hasRecord":false},"crypto":{"xcoin":0,"gne":0,"shung":0,"lme":0},"armor":0,"hunger":32.79999999999995,"stress":0,"fitbit":{"food":90,"thirst":90},"fingerprint":"Gk132p54IWA8297","inside":{"apartment":[]},"craftingrep":0,"phonedata":{"SerialNumber":38821523,"InstalledApps":[]},"bloodtype":"AB-","tracker":false,"callsign":"ORIGEN","thirst":39.20000000000004,"walletid":"QB-89589578","isdead":false,"injail":0,"ishandcuffed":false,"inlaststand":false,"phone":[]}', '[{"name":"weed_whitewidow","created":1719500603,"slot":1,"type":"item","amount":4,"info":{"quality":100}},{"name":"cutter","created":1719500839,"slot":2,"type":"item","amount":2,"info":{"quality":100}},{"name":"empty_weed_bag","created":1719500847,"slot":3,"type":"item","amount":1,"info":{"quality":100}},{"name":"weedbud","created":1719500856,"slot":4,"type":"item","amount":3,"info":{"quality":100}},{"name":"weed_seed","created":1719500875,"slot":5,"type":"item","amount":7,"info":{"quality":100}},{"name":"trowel","created":1719500785,"slot":6,"type":"item","amount":10,"info":{"quality":100}},{"name":"dust","created":1719501037,"slot":7,"type":"item","amount":1,"info":{"quality":100}},{"name":"weed_nutrition","created":1719501038,"slot":8,"type":"item","amount":6,"info":{"quality":100}},{"name":"body_cam","created":1719501877,"slot":9,"type":"item","amount":1,"info":{"quality":100}},{"name":"empty_evidence_bag","created":1719501986,"slot":10,"type":"item","amount":1,"info":{"quality":100}}]', '2024-07-04 22:45:17', 0, NULL, NULL, NULL, NULL, NULL, 1, 0, 1, 0, NULL, 0, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '', '', NULL, NULL, '{"AnonimTweet":0,"PhoneCheck":0,"SendAllDM":0,"xp":112,"LspdActivePersonel":1718933055,"LocationCheck":0,"CarLock":0,"PhonefromName":0,"BankHack":0,"CctvCamera":1718933656}');

-- Dumping structure for table origenv2qb.playerskins
CREATE TABLE IF NOT EXISTS `playerskins` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `citizenid` varchar(11) NOT NULL,
  `model` varchar(255) NOT NULL,
  `skin` text NOT NULL,
  `active` tinyint(4) NOT NULL DEFAULT 1,
  PRIMARY KEY (`id`),
  KEY `citizenid` (`citizenid`),
  KEY `active` (`active`)
) ENGINE=InnoDB AUTO_INCREMENT=56 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Dumping data for table origenv2qb.playerskins: ~0 rows (approximately)
INSERT INTO `playerskins` (`id`, `citizenid`, `model`, `skin`, `active`) VALUES
	(55, 'ZEN90470', '1885233650', '{"beard":{"defaultTexture":1,"texture":1,"defaultItem":-1,"item":13},"chimp_bone_width":{"defaultTexture":0,"texture":0,"defaultItem":0,"item":0},"cheek_1":{"defaultTexture":0,"texture":0,"defaultItem":0,"item":0},"ageing":{"defaultTexture":0,"texture":0,"defaultItem":-1,"item":-1},"pants":{"defaultTexture":0,"texture":0,"defaultItem":0,"item":144},"torso2":{"defaultTexture":0,"texture":3,"defaultItem":0,"item":414},"chimp_hole":{"defaultTexture":0,"texture":0,"defaultItem":0,"item":0},"facemix":{"defaultShapeMix":0.0,"defaultSkinMix":0.0,"shapeMix":0,"skinMix":0},"t-shirt":{"defaultTexture":0,"texture":0,"defaultItem":1,"item":229},"decals":{"defaultTexture":0,"texture":0,"defaultItem":0,"item":0},"face2":{"defaultTexture":0,"texture":0,"defaultItem":0,"item":0},"neck_thikness":{"defaultTexture":0,"texture":0,"defaultItem":0,"item":0},"arms":{"defaultTexture":0,"texture":0,"defaultItem":0,"item":1},"eye_opening":{"defaultTexture":0,"texture":0,"defaultItem":0,"item":0},"face":{"defaultTexture":0,"texture":0,"defaultItem":0,"item":0},"shoes":{"defaultTexture":0,"texture":3,"defaultItem":1,"item":107},"chimp_bone_lenght":{"defaultTexture":0,"texture":0,"defaultItem":0,"item":0},"lips_thickness":{"defaultTexture":0,"texture":0,"defaultItem":0,"item":0},"nose_0":{"defaultTexture":0,"texture":0,"defaultItem":0,"item":0},"jaw_bone_back_lenght":{"defaultTexture":0,"texture":0,"defaultItem":0,"item":0},"nose_2":{"defaultTexture":0,"texture":0,"defaultItem":0,"item":0},"makeup":{"defaultTexture":1,"texture":1,"defaultItem":-1,"item":-1},"moles":{"defaultTexture":0,"texture":0,"defaultItem":-1,"item":-1},"ear":{"defaultTexture":0,"texture":0,"defaultItem":-1,"item":9},"mask":{"defaultTexture":0,"texture":0,"defaultItem":0,"item":0},"bracelet":{"defaultTexture":0,"texture":0,"defaultItem":-1,"item":-1},"eyebrown_high":{"defaultTexture":0,"texture":0,"defaultItem":0,"item":0},"eye_color":{"defaultTexture":0,"texture":0,"defaultItem":-1,"item":-1},"lipstick":{"defaultTexture":1,"texture":1,"defaultItem":-1,"item":-1},"cheek_3":{"defaultTexture":0,"texture":0,"defaultItem":0,"item":0},"bag":{"defaultTexture":0,"texture":0,"defaultItem":0,"item":0},"nose_5":{"defaultTexture":0,"texture":0,"defaultItem":0,"item":0},"nose_4":{"defaultTexture":0,"texture":0,"defaultItem":0,"item":0},"nose_3":{"defaultTexture":0,"texture":0,"defaultItem":0,"item":0},"nose_1":{"defaultTexture":0,"texture":0,"defaultItem":0,"item":0},"chimp_bone_lowering":{"defaultTexture":0,"texture":0,"defaultItem":0,"item":0},"vest":{"defaultTexture":0,"texture":0,"defaultItem":0,"item":0},"eyebrown_forward":{"defaultTexture":0,"texture":0,"defaultItem":0,"item":0},"accessory":{"defaultTexture":0,"texture":0,"defaultItem":0,"item":12},"hair":{"defaultTexture":0,"texture":0,"defaultItem":0,"item":12},"watch":{"defaultTexture":0,"texture":0,"defaultItem":-1,"item":14},"jaw_bone_width":{"defaultTexture":0,"texture":0,"defaultItem":0,"item":0},"hat":{"defaultTexture":0,"texture":4,"defaultItem":-1,"item":106},"blush":{"defaultTexture":1,"texture":1,"defaultItem":-1,"item":-1},"cheek_2":{"defaultTexture":0,"texture":0,"defaultItem":0,"item":0},"glass":{"defaultTexture":0,"texture":0,"defaultItem":0,"item":0},"eyebrows":{"defaultTexture":1,"texture":1,"defaultItem":-1,"item":30}}', 1);

-- Dumping structure for table origenv2qb.player_contacts
CREATE TABLE IF NOT EXISTS `player_contacts` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `citizenid` varchar(50) DEFAULT NULL,
  `name` varchar(50) DEFAULT NULL,
  `number` varchar(50) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `citizenid` (`citizenid`)
) ENGINE=InnoDB AUTO_INCREMENT=12 DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

-- Dumping data for table origenv2qb.player_contacts: ~0 rows (approximately)

-- Dumping structure for table origenv2qb.player_gallery
CREATE TABLE IF NOT EXISTS `player_gallery` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `identifier` text NOT NULL,
  `resim` text NOT NULL,
  `data` text NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=11 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Dumping data for table origenv2qb.player_gallery: ~0 rows (approximately)

-- Dumping structure for table origenv2qb.player_garages
CREATE TABLE IF NOT EXISTS `player_garages` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `garage` varchar(50) NOT NULL,
  `garage_type` varchar(50) DEFAULT NULL,
  `citizenid` varchar(50) DEFAULT NULL,
  `metadata` varchar(50) DEFAULT '{}',
  `permissions` varchar(50) DEFAULT '{}',
  `time_of_purchase` varchar(50) DEFAULT NULL,
  `slots` int(11) unsigned zerofill DEFAULT NULL,
  `tier` int(11) unsigned zerofill DEFAULT NULL,
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE KEY `garage` (`garage`) USING BTREE,
  KEY `id` (`id`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=8 DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

-- Dumping data for table origenv2qb.player_garages: ~0 rows (approximately)

-- Dumping structure for table origenv2qb.player_houses
CREATE TABLE IF NOT EXISTS `player_houses` (
  `id` int(255) NOT NULL AUTO_INCREMENT,
  `house` varchar(50) NOT NULL,
  `identifier` varchar(50) DEFAULT NULL,
  `citizenid` varchar(11) DEFAULT NULL,
  `keyholders` text DEFAULT NULL,
  `decorations` text DEFAULT NULL,
  `stash` text DEFAULT NULL,
  `outfit` text DEFAULT NULL,
  `logout` text DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `house` (`house`),
  KEY `citizenid` (`citizenid`),
  KEY `identifier` (`identifier`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Dumping data for table origenv2qb.player_houses: ~0 rows (approximately)
INSERT INTO `player_houses` (`id`, `house`, `identifier`, `citizenid`, `keyholders`, `decorations`, `stash`, `outfit`, `logout`) VALUES
	(1, 'south rockford dr1', 'license:407894f5ace9e794698132ea12dd8807b5ae71bc', 'ZEN90470', '["ZEN90470"]', NULL, NULL, NULL, NULL);

-- Dumping structure for table origenv2qb.player_jobs
CREATE TABLE IF NOT EXISTS `player_jobs` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `jobname` varchar(50) DEFAULT NULL,
  `employees` text DEFAULT NULL,
  `maxEmployee` tinyint(11) DEFAULT 15,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=129 DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

-- Dumping data for table origenv2qb.player_jobs: ~0 rows (approximately)

-- Dumping structure for table origenv2qb.player_mails
CREATE TABLE IF NOT EXISTS `player_mails` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `citizenid` varchar(50) DEFAULT NULL,
  `sender` varchar(50) DEFAULT NULL,
  `subject` varchar(50) DEFAULT NULL,
  `message` text DEFAULT NULL,
  `read` tinyint(4) DEFAULT 0,
  `mailid` int(11) DEFAULT NULL,
  `date` timestamp NULL DEFAULT current_timestamp(),
  `button` text DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `citizenid` (`citizenid`)
) ENGINE=InnoDB AUTO_INCREMENT=57 DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

-- Dumping data for table origenv2qb.player_mails: ~4 rows (approximately)
INSERT INTO `player_mails` (`id`, `citizenid`, `sender`, `subject`, `message`, `read`, `mailid`, `date`, `button`) VALUES
	(53, 'ZEN90470', 'Jonathan Sanders', 'New Crypto Miner', 'Congrats on the crypto miner. Want some info? The default GTX 480 is very slow, I reccomend to install a newer and more powerfull graphics card for faster mining speeds. This industry can be very lucriticve and volatile. Good luck, Johnny', 0, 118991, '2024-06-21 01:42:03', NULL),
	(54, 'ZEN90470', 'Jonathan Sanders', 'New Graphics Card', 'Congrats on the new graphics card. Make the most out of it, it is one profitable side hustle or buisness. Congrats, Johnny', 0, 203912, '2024-06-21 01:43:20', NULL),
	(55, 'ZEN90470', 'Turner’s Auto Wrecking', 'Vehicle List', 'You Can Only Demolish A Number Of Vehicles.<br />You Can Keep Everything You Demolish For Yourself As Long As You Dont Bother Me.<br /><br /><strong>Vehicle List:</strong><br />Ocelot Jackal<br />Dundreary Stretch<br />Grotti Turismo R<br />Übermacht Zion<br />Albany Washington<br />Vapid Dominator<br />Declasse Asea<br />Lampadati Felon<br />Cheval Picador<br />Albany Cavalcade II<br />Declasse Rhapsody<br />Karin Sultan<br />Maxwell Asbo<br />Albany Virgo<br />Vapid Blade<br />Declasse Sabre GT Turbo<br />Dewbauchee Exemplar<br />Bravado Buffalo S<br />Vapid Bobcat XL Open<br />Bravado Gauntlet<br />Obey 9F<br />Bravado Buffalo<br />Dinka Blista Compact<br />Dundreary Landstalker<br />Pfister Comet<br />Übermacht Oracle<br />Vapid Sandking SWB<br />Bravado Banshee<br />Nagasaki Carbon RS<br />Albany Alpha<br />', 0, 248117, '2024-06-21 20:38:16', '[]'),
	(56, 'ZEN90470', 'The Boss', 'New Target', 'So you are intrested in making some money? good... go get yourself a Gun and make it happen... sending you the location now.', 0, 721550, '2024-06-21 21:23:49', NULL);

-- Dumping structure for table origenv2qb.player_notes
CREATE TABLE IF NOT EXISTS `player_notes` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `identifier` text NOT NULL,
  `baslik` text NOT NULL,
  `aciklama` text NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Dumping data for table origenv2qb.player_notes: ~0 rows (approximately)

-- Dumping structure for table origenv2qb.player_outfits
CREATE TABLE IF NOT EXISTS `player_outfits` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `citizenid` varchar(11) DEFAULT NULL,
  `outfitname` varchar(50) NOT NULL,
  `model` varchar(50) DEFAULT NULL,
  `skin` text DEFAULT NULL,
  `outfitId` varchar(50) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `citizenid` (`citizenid`),
  KEY `outfitId` (`outfitId`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Dumping data for table origenv2qb.player_outfits: ~1 rows (approximately)

-- Dumping structure for table origenv2qb.player_vehicles
CREATE TABLE IF NOT EXISTS `player_vehicles` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `license` varchar(50) DEFAULT NULL,
  `citizenid` varchar(50) DEFAULT NULL,
  `vehicle` varchar(50) DEFAULT NULL,
  `hash` varchar(50) DEFAULT NULL,
  `damage` longtext DEFAULT NULL,
  `mods` text CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL,
  `plate` varchar(15) NOT NULL,
  `fakeplate` varchar(50) DEFAULT NULL,
  `garage` varchar(50) DEFAULT 'pillboxgarage',
  `fuel` int(11) DEFAULT 100,
  `engine` float DEFAULT 1000,
  `body` float DEFAULT 1000,
  `state` int(11) DEFAULT 1,
  `depotprice` int(11) NOT NULL DEFAULT 0,
  `drivingdistance` int(50) DEFAULT NULL,
  `status` text DEFAULT NULL,
  `balance` int(11) NOT NULL DEFAULT 0,
  `paymentamount` int(11) NOT NULL DEFAULT 0,
  `paymentsleft` int(11) NOT NULL DEFAULT 0,
  `financetime` int(11) NOT NULL DEFAULT 0,
  `globals` text CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL,
  `vin_scratch` int(11) DEFAULT 0,
  `timestamp` varchar(500) DEFAULT '0',
  `datefinish` date NOT NULL DEFAULT '2025-06-01',
  `rentfinish` date NOT NULL DEFAULT '2025-06-01',
  `nosColour` text DEFAULT NULL,
  `traveldistance` int(50) DEFAULT 0,
  `noslevel` int(10) DEFAULT 0,
  `hasnitro` tinyint(4) DEFAULT 0,
  `logs` longtext DEFAULT '[]',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE KEY `UK_playervehicles_plate` (`plate`) USING BTREE,
  KEY `plate` (`plate`) USING BTREE,
  KEY `citizenid` (`citizenid`) USING BTREE,
  KEY `license` (`license`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=47 DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

-- Dumping data for table origenv2qb.player_vehicles: ~7 rows (approximately)
INSERT INTO `player_vehicles` (`id`, `license`, `citizenid`, `vehicle`, `hash`, `damage`, `mods`, `plate`, `fakeplate`, `garage`, `fuel`, `engine`, `body`, `state`, `depotprice`, `drivingdistance`, `status`, `balance`, `paymentamount`, `paymentsleft`, `financetime`, `globals`, `vin_scratch`, `timestamp`, `datefinish`, `rentfinish`, `nosColour`, `traveldistance`, `noslevel`, `hasnitro`, `logs`) VALUES
	(39, 'license:407894f5ace9e794698132ea12dd8807b5ae71bc', 'KYE11753', 't20', '1663218586', NULL, '{"tyreSmokeColor":[255,255,255],"model":1663218586,"modVanityPlate":-1,"modPlateHolder":-1,"modTank":-1,"bodyHealth":1000.0592475178704,"modFrontBumper":-1,"modKit21":-1,"modStruts":-1,"modRightFender":-1,"interiorColor":0,"modFrame":-1,"modBackWheels":-1,"modSeats":-1,"engineHealth":1000.0592475178704,"modShifterLeavers":-1,"doorStatus":{"1":false,"2":false,"3":false,"4":false,"5":false,"0":false},"plate":"46TFK463","modTrimA":-1,"tireBurstCompletely":{"1":false,"2":false,"3":false,"4":false,"5":false,"0":false},"modFrontWheels":-1,"tankHealth":1000.0592475178704,"modAPlate":-1,"modBrakes":-1,"pearlescentColor":3,"modTurbo":false,"modExhaust":-1,"modKit17":-1,"modArchCover":-1,"neonEnabled":[false,false,false,false],"modTransmission":-1,"tireBurstState":{"1":false,"2":false,"3":false,"4":false,"5":false,"0":false},"extras":[],"modCustomTiresF":false,"modOrnaments":-1,"modSmokeEnabled":false,"dirtLevel":0.0,"windowStatus":{"1":true,"2":false,"3":false,"4":false,"5":false,"6":true,"7":true,"0":true},"liveryRoof":-1,"modRearBumper":-1,"modKit19":-1,"color1":7,"windowTint":-1,"modEngine":-1,"color2":7,"tireHealth":{"1":1000.0,"2":1000.0,"3":1000.0,"0":1000.0},"wheelColor":0,"modSteeringWheel":-1,"fuelLevel":44.48238114455976,"modSideSkirt":-1,"oilLevel":4.76596940834568,"modCustomTiresR":false,"wheels":7,"modHorns":-1,"modXenon":false,"neonColor":[255,255,255],"modDoorSpeaker":-1,"xenonColor":255,"wheelSize":0.0,"modArmor":-1,"modSuspension":-1,"modSpeakers":-1,"modSpoilers":-1,"modDashboard":-1,"wheelWidth":0.0,"modKit49":-1,"modAirFilter":-1,"modRoof":-1,"modDial":-1,"modHood":-1,"modWindows":-1,"modKit47":-1,"modTrunk":-1,"modLivery":-1,"modTrimB":-1,"dashboardColor":0,"plateIndex":0,"modFender":-1,"modEngineBlock":-1,"modHydrolic":-1,"modAerials":-1,"modGrille":-1}', '46TFK463', NULL, 'ApartmentsGarage', 44, 1000, 1000, 1, 0, NULL, NULL, 0, 0, 0, 0, NULL, 0, '0', '2025-06-01', '2025-06-01', NULL, 0, 0, 0, '[{"type":"Stored","garage":"Alta Apartments","time":"2024-06-20-21:34"}]'),
	(40, 'license:407894f5ace9e794698132ea12dd8807b5ae71bc', 'ZEN90470', 'sultan2', '872704284', NULL, '{"modNitrous":-1,"modVanityPlate":-1,"wheelColor":156,"modFrame":-1,"modEngine":-1,"modTrunk":-1,"modTurbo":false,"wheelWidth":0.0,"modRoof":-1,"modXenon":false,"dirtLevel":0,"bodyHealth":1000,"modArchCover":-1,"neonEnabled":[false,false,false,false],"modPlateHolder":-1,"plate":"45RQM994","modTank":-1,"oilLevel":5,"extras":[],"color1":50,"modWindows":-1,"neonColor":[255,255,255],"modRearBumper":-1,"modTrimA":-1,"modSideSkirt":-1,"paintType2":0,"color2":50,"xenonColor":255,"engineHealth":1000,"modOrnaments":-1,"wheels":5,"modStruts":-1,"modTrimB":-1,"modGrille":-1,"modArmor":-1,"modCustomTiresF":false,"modSuspension":-1,"modSubwoofer":-1,"modDial":-1,"tyres":[],"modSeats":-1,"modFender":-1,"windows":[4,5],"modExhaust":-1,"wheelSize":0.0,"modFrontWheels":-1,"modBrakes":-1,"modRoofLivery":-1,"modDoorSpeaker":-1,"modSpoilers":-1,"fuelLevel":50,"doors":[],"modLightbar":-1,"bulletProofTyres":true,"modBackWheels":-1,"modRightFender":-1,"modDashboard":-1,"modHorns":-1,"modSteeringWheel":-1,"tyreSmokeColor":[255,255,255],"modTransmission":-1,"driftTyres":false,"tankHealth":1000,"model":872704284,"modFrontBumper":-1,"modShifterLeavers":-1,"modSpeakers":-1,"plateIndex":0,"modAerials":-1,"paintType1":0,"modAirFilter":-1,"interiorColor":3,"dashboardColor":160,"modLivery":-1,"modHydrolic":-1,"modCustomTiresR":false,"pearlescentColor":57,"modDoorR":-1,"modEngineBlock":-1,"modHydraulics":false,"windowTint":-1,"modHood":-1,"modSmokeEnabled":false,"modAPlate":-1}', '45RQM994', NULL, 'pillboxgarage', 100, 1000, 1000, 1, 0, NULL, NULL, 0, 0, 0, 0, NULL, 0, '0', '2025-06-01', '2025-06-01', NULL, 0, 0, 0, '[]'),
	(41, 'license:407894f5ace9e794698132ea12dd8807b5ae71bc', 'ZEN90470', 'sultan', '970598228', NULL, '{"modRearBumper":-1,"modKit47":-1,"modTank":-1,"modSeats":-1,"tyreSmokeColor":[255,255,255],"modFrontBumper":-1,"modTrunk":-1,"wheelSize":1.0,"modCustomTiresR":false,"modArmor":-1,"wheelWidth":1.0,"wheelColor":156,"fuelLevel":34.1561140931441,"modSmokeEnabled":false,"modWindows":-1,"tireBurstState":{"1":false,"2":false,"3":false,"4":false,"5":false,"0":false},"modSteeringWheel":-1,"oilLevel":4.76596940834568,"modStruts":-1,"tireBurstCompletely":{"1":false,"2":false,"3":false,"4":false,"5":false,"0":false},"modRightFender":-1,"model":970598228,"windowTint":-1,"modOrnaments":-1,"modRoof":-1,"modTrimA":-1,"doorStatus":{"1":false,"2":false,"3":false,"4":false,"5":false,"0":false},"color2":1,"modShifterLeavers":-1,"wheels":0,"modDial":-1,"dirtLevel":0.0,"modHorns":-1,"tankHealth":1000.0592475178704,"modFender":-1,"modTrimB":-1,"modSuspension":-1,"neonColor":[255,255,255],"modKit49":-1,"modCustomTiresF":false,"modVanityPlate":-1,"modSideSkirt":-1,"color1":1,"modArchCover":-1,"modFrame":-1,"modTurbo":false,"tireHealth":{"1":1000.0,"2":1000.0,"3":1000.0,"0":1000.0},"plate":"68YYI312","modBackWheels":-1,"modSpeakers":-1,"modKit17":-1,"modKit19":-1,"neonEnabled":[false,false,false,false],"pearlescentColor":5,"plateIndex":3,"modLivery":-1,"extras":{"10":false,"12":true},"modAirFilter":-1,"modGrille":-1,"windowStatus":{"1":true,"2":true,"3":true,"4":false,"5":false,"6":true,"7":true,"0":true},"modHydrolic":-1,"modPlateHolder":-1,"liveryRoof":-1,"modBrakes":-1,"engineHealth":1000.0592475178704,"modEngineBlock":-1,"modFrontWheels":-1,"modXenon":false,"modExhaust":-1,"dashboardColor":0,"bodyHealth":1000.0592475178704,"xenonColor":255,"modSpoilers":-1,"modKit21":-1,"interiorColor":0,"modAPlate":-1,"modTransmission":-1,"modAerials":-1,"modEngine":-1,"modDoorSpeaker":-1,"modHood":-1,"modDashboard":-1}', '68YYI312', NULL, 'ApartmentsGarage', 35, 1000, 1000, 1, 0, NULL, NULL, 0, 0, 0, 0, NULL, 0, '0', '2025-06-01', '2025-06-01', NULL, 0, 0, 0, '[{"time":"2024-06-20-22:32","garage":"Alta Apartments","type":"Stored"},{"time":"2024-06-20-22:33","garage":"Alta Apartments","type":"Take Out"},{"time":"2024-06-27-13:16","garage":"Depot Lot","type":"Take Depot"},{"time":"2024-06-27-13:16","garage":"Alta Apartments","type":"Stored"}]'),
	(42, 'license:407894f5ace9e794698132ea12dd8807b5ae71bc', 'ZEN90470', 't20', '1663218586', NULL, '{"modBrakes":-1,"modKit47":-1,"pearlescentColor":3,"modAerials":-1,"modOrnaments":-1,"modShifterLeavers":-1,"modArmor":-1,"modTransmission":-1,"modBackWheels":-1,"modSteeringWheel":-1,"modHorns":-1,"modStruts":-1,"modTrimB":-1,"modSeats":-1,"modAirFilter":-1,"modRoof":-1,"modArchCover":-1,"tireHealth":{"1":1000.0,"2":1000.0,"3":1000.0,"0":1000.0},"modTrunk":-1,"modDoorSpeaker":-1,"modTank":-1,"windowStatus":{"1":true,"2":false,"3":false,"4":false,"5":false,"6":false,"7":true,"0":true},"bodyHealth":997.6762628136975,"color1":7,"modSmokeEnabled":false,"modKit21":-1,"modDial":-1,"extras":[],"plateIndex":0,"neonEnabled":[false,false,false,false],"modAPlate":-1,"modHydrolic":-1,"modTurbo":false,"tireBurstCompletely":{"1":false,"2":false,"3":false,"4":false,"5":false,"0":false},"wheelSize":1.0,"tyreSmokeColor":[255,255,255],"engineHealth":1000.0592475178704,"modKit49":-1,"modKit17":-1,"modWindows":-1,"modRearBumper":-1,"modExhaust":-1,"model":1663218586,"modLivery":-1,"wheelWidth":1.0,"modSpeakers":-1,"doorStatus":{"1":false,"2":false,"3":false,"4":false,"5":false,"0":false},"wheels":7,"modFrontBumper":-1,"xenonColor":255,"wheelColor":0,"modCustomTiresF":false,"color2":7,"oilLevel":4.76596940834568,"liveryRoof":-1,"modFrontWheels":-1,"modTrimA":-1,"modRightFender":-1,"modKit19":-1,"dirtLevel":0.0,"modHood":-1,"windowTint":-1,"tankHealth":1000.0592475178704,"plate":"60FFV170","modSideSkirt":-1,"modDashboard":-1,"modVanityPlate":-1,"modGrille":-1,"tireBurstState":{"1":false,"2":false,"3":false,"4":false,"5":false,"0":false},"fuelLevel":40.51073997093835,"modSpoilers":-1,"modEngineBlock":-1,"modFrame":-1,"interiorColor":0,"dashboardColor":0,"modFender":-1,"modSuspension":-1,"modEngine":-1,"neonColor":[255,255,255],"modPlateHolder":-1,"modCustomTiresR":false,"modXenon":false}', '60FFV170', NULL, 'ApartmentsGarage', 40, 1000, 998, 1, 0, NULL, NULL, 0, 0, 0, 0, NULL, 0, '0', '2025-06-01', '2025-06-01', NULL, 0, 0, 0, '[{"garage":"Alta Apartments","type":"Stored","time":"2024-06-20-22:32"},{"garage":"Alta Apartments","type":"Take Out","time":"2024-06-20-22:33"},{"garage":"Alta Apartments","type":"Stored","time":"2024-06-20-22:33"},{"garage":"Alta Apartments","type":"Take Out","time":"2024-06-20-22:35"},{"garage":"Alta Apartments","type":"Take Out","time":"2024-06-20-22:36"},{"garage":"Alta Apartments","type":"Stored","time":"2024-06-20-22:36"}]'),
	(43, 'license:407894f5ace9e794698132ea12dd8807b5ae71bc', 'ZEN90470', 'bati', '-114291515', NULL, '{"modBrakes":-1,"modKit47":-1,"pearlescentColor":0,"modAerials":-1,"modOrnaments":-1,"modShifterLeavers":-1,"modArmor":-1,"modTransmission":-1,"modBackWheels":-1,"modSteeringWheel":-1,"modHorns":-1,"modStruts":-1,"modTrimB":-1,"modSeats":-1,"modAirFilter":-1,"modRoof":-1,"modArchCover":-1,"tireHealth":{"1":1000.0,"2":0.0,"3":0.0,"0":1000.0},"modTrunk":-1,"modDoorSpeaker":-1,"modTank":-1,"windowStatus":{"1":false,"2":false,"3":false,"4":false,"5":false,"6":true,"7":false,"0":false},"bodyHealth":1000.0592475178704,"color1":27,"modSmokeEnabled":false,"modKit21":-1,"modDial":-1,"extras":[],"plateIndex":0,"neonEnabled":[false,false,false,false],"modAPlate":-1,"modHydrolic":-1,"modTurbo":false,"tireBurstCompletely":{"1":false,"2":false,"3":false,"4":false,"5":false,"0":false},"wheelSize":1.0,"tyreSmokeColor":[255,255,255],"engineHealth":1000.0592475178704,"modKit49":-1,"modKit17":-1,"modWindows":-1,"modRearBumper":-1,"modExhaust":-1,"model":-114291515,"modLivery":-1,"wheelWidth":1.0,"modSpeakers":-1,"doorStatus":{"1":false,"2":false,"3":false,"4":false,"5":false,"0":false},"wheels":6,"modFrontBumper":-1,"xenonColor":255,"wheelColor":27,"modCustomTiresF":false,"color2":27,"oilLevel":4.76596940834568,"liveryRoof":-1,"modFrontWheels":-1,"modTrimA":-1,"modRightFender":-1,"modKit19":-1,"dirtLevel":0.0,"modHood":-1,"windowTint":-1,"tankHealth":1000.0592475178704,"plate":"62IKT920","modSideSkirt":-1,"modDashboard":-1,"modVanityPlate":-1,"modGrille":-1,"tireBurstState":{"1":false,"2":false,"3":false,"4":false,"5":false,"0":false},"fuelLevel":61.16327407376967,"modSpoilers":-1,"modEngineBlock":-1,"modFrame":-1,"interiorColor":0,"dashboardColor":0,"modFender":-1,"modSuspension":-1,"modEngine":-1,"neonColor":[255,255,255],"modPlateHolder":-1,"modCustomTiresR":false,"modXenon":false}', '62IKT920', NULL, 'ApartmentsGarage', 61, 1000, 1000, 1, 0, NULL, NULL, 0, 0, 0, 0, NULL, 0, '0', '2025-06-01', '2025-06-01', NULL, 0, 0, 0, '[{"garage":"Alta Apartments","type":"Stored","time":"2024-06-20-22:34"},{"garage":"Alta Apartments","type":"Take Out","time":"2024-06-20-22:34"},{"garage":"Alta Apartments","type":"Take Out","time":"2024-06-20-22:36"},{"garage":"Alta Apartments","type":"Stored","time":"2024-06-20-22:37"}]'),
	(45, 'license:407894f5ace9e794698132ea12dd8807b5ae71bc', 'ZEN90470', 'deluxo', '1483171323', NULL, '{"modSpeakers":-1,"modHorns":-1,"modStruts":-1,"modAPlate":-1,"modEngineBlock":-1,"modFrontBumper":-1,"modRoof":-1,"color2":38,"dirtLevel":4.76596940834568,"modTurbo":false,"modArchCover":-1,"modBackWheels":-1,"modKit19":-1,"modRearBumper":-1,"bodyHealth":1000.0592475178704,"fuelLevel":99.29102934053518,"modTrunk":-1,"wheels":1,"modVanityPlate":-1,"modRightFender":-1,"modShifterLeavers":-1,"modSeats":-1,"tyreSmokeColor":[255,255,255],"modDashboard":-1,"modDoorSpeaker":-1,"modXenon":false,"modAerials":-1,"modTrimA":-1,"wheelWidth":1.0,"modKit49":-1,"neonColor":[255,255,255],"tireHealth":{"1":1000.0,"2":1000.0,"3":1000.0,"0":1000.0},"modLivery":-1,"modFrontWheels":-1,"modSideSkirt":-1,"engineHealth":1000.0592475178704,"modFender":-1,"plate":"ORIGENV2","modWindows":-1,"modFrame":-1,"modExhaust":-1,"interiorColor":19,"doorStatus":{"1":false,"2":false,"3":false,"4":false,"5":false,"0":false},"modTank":-1,"tireBurstState":{"1":false,"2":false,"3":false,"4":false,"5":false,"0":false},"modSmokeEnabled":false,"modDial":-1,"modTransmission":-1,"model":1483171323,"tireBurstCompletely":{"1":false,"2":false,"3":false,"4":false,"5":false,"0":false},"modCustomTiresF":false,"dashboardColor":156,"tankHealth":1000.0592475178704,"modHydrolic":-1,"modTrimB":-1,"wheelColor":0,"extras":[],"modSuspension":-1,"modOrnaments":-1,"pearlescentColor":24,"modAirFilter":-1,"wheelSize":1.0,"color1":38,"modKit47":-1,"plateIndex":0,"modKit17":-1,"xenonColor":255,"modEngine":-1,"liveryRoof":-1,"modArmor":-1,"modKit21":-1,"modHood":-1,"modSteeringWheel":-1,"modPlateHolder":-1,"oilLevel":6.35462587779425,"modSpoilers":-1,"modGrille":-1,"neonEnabled":[false,false,false,false],"modCustomTiresR":false,"modBrakes":-1,"windowTint":-1,"windowStatus":{"1":true,"2":true,"3":true,"4":false,"5":false,"6":true,"7":true,"0":true}}', 'OrigenV2', NULL, 'motelgarage', 99, 1000, 1000, 1, 0, NULL, NULL, 0, 0, 0, 0, NULL, 0, '0', '2025-06-01', '2025-06-01', NULL, 0, 0, 0, '[{"time":"2024-06-21-02:23","garage":"Alta Apartments","type":"Take Out"},{"time":"2024-06-21-02:23","garage":"Alta Apartments","type":"Stored"},{"time":"2024-06-27-13:35","garage":"Motel Parking","type":"Take Out"},{"time":"2024-06-27-13:35","garage":"Motel Parking","type":"Stored"}]'),
	(46, 'license:407894f5ace9e794698132ea12dd8807b5ae71bc', 'ZEN90470', 'neon', '-1848994066', NULL, '{"modSpeakers":-1,"modHorns":-1,"modStruts":-1,"modAPlate":-1,"modEngineBlock":-1,"modFrontBumper":-1,"modRoof":-1,"color2":0,"dirtLevel":0.0,"modTurbo":false,"modArchCover":-1,"modBackWheels":-1,"modKit19":-1,"modRearBumper":-1,"bodyHealth":1000.0592475178704,"fuelLevel":24.62417527645272,"modTrunk":-1,"wheels":0,"modVanityPlate":-1,"modRightFender":-1,"modShifterLeavers":-1,"modSeats":-1,"tyreSmokeColor":[255,255,255],"modDashboard":-1,"modDoorSpeaker":-1,"modXenon":false,"modAerials":-1,"modTrimA":-1,"wheelWidth":1.0,"modKit49":-1,"neonColor":[255,255,255],"tireHealth":{"1":1000.0,"2":1000.0,"3":1000.0,"0":1000.0},"modLivery":-1,"modFrontWheels":-1,"modSideSkirt":-1,"engineHealth":1000.0592475178704,"modFender":-1,"plate":"86TIV014","modWindows":-1,"modFrame":-1,"modExhaust":-1,"interiorColor":93,"doorStatus":{"1":false,"2":false,"3":false,"4":false,"5":false,"0":false},"modTank":-1,"tireBurstState":{"1":false,"2":false,"3":false,"4":false,"5":false,"0":false},"modSmokeEnabled":false,"modDial":-1,"modTransmission":-1,"model":-1848994066,"tireBurstCompletely":{"1":false,"2":false,"3":false,"4":false,"5":false,"0":false},"modCustomTiresF":false,"dashboardColor":65,"tankHealth":1000.0592475178704,"modHydrolic":-1,"modTrimB":-1,"wheelColor":0,"extras":[],"modSuspension":-1,"modOrnaments":-1,"pearlescentColor":73,"modAirFilter":-1,"wheelSize":1.0,"color1":64,"modKit47":-1,"plateIndex":0,"modKit17":-1,"xenonColor":255,"modEngine":-1,"liveryRoof":-1,"modArmor":-1,"modKit21":-1,"modHood":-1,"modSteeringWheel":-1,"modPlateHolder":-1,"oilLevel":4.76596940834568,"modSpoilers":-1,"modGrille":-1,"neonEnabled":[false,false,false,false],"modCustomTiresR":false,"modBrakes":-1,"windowTint":-1,"windowStatus":{"1":true,"2":true,"3":true,"4":false,"5":false,"6":true,"7":true,"0":true}}', '86TIV014', NULL, 'motelgarage', 25, 1000, 1000, 1, 0, NULL, NULL, 0, 0, 0, 0, NULL, 0, '0', '2025-06-01', '2025-06-01', NULL, 0, 0, 0, '[{"time":"2024-06-27-13:31","garage":"Motel Parking","type":"Stored"},{"time":"2024-06-27-13:35","garage":"Motel Parking","type":"Take Out"},{"time":"2024-06-27-13:35","garage":"Motel Parking","type":"Stored"}]');

-- Dumping structure for table origenv2qb.player_warns
CREATE TABLE IF NOT EXISTS `player_warns` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `senderIdentifier` varchar(50) DEFAULT NULL,
  `targetIdentifier` varchar(50) DEFAULT NULL,
  `reason` text DEFAULT NULL,
  `warnId` varchar(50) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Dumping data for table origenv2qb.player_warns: ~0 rows (approximately)

-- Dumping structure for table origenv2qb.punchmachine
CREATE TABLE IF NOT EXISTS `punchmachine` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(50) DEFAULT NULL,
  `score` varchar(50) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=664 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Dumping data for table origenv2qb.punchmachine: ~0 rows (approximately)
INSERT INTO `punchmachine` (`id`, `name`, `score`) VALUES
	(663, 'Origen V2', '640');

-- Dumping structure for table origenv2qb.races
CREATE TABLE IF NOT EXISTS `races` (
  `owner` varchar(50) DEFAULT NULL,
  `name` varchar(50) DEFAULT NULL,
  `reward` int(11) DEFAULT NULL,
  `date` longtext DEFAULT NULL,
  `maxplayers` int(11) DEFAULT NULL,
  `route` longtext DEFAULT NULL,
  `id` bigint(20) DEFAULT NULL,
  `players` longtext DEFAULT NULL,
  `luadate` longtext DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

-- Dumping data for table origenv2qb.races: ~0 rows (approximately)

-- Dumping structure for table origenv2qb.race_tracks
CREATE TABLE IF NOT EXISTS `race_tracks` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(50) NOT NULL,
  `checkpoints` text DEFAULT NULL,
  `records` text DEFAULT NULL,
  `creator` varchar(50) DEFAULT NULL,
  `distance` int(11) DEFAULT NULL,
  `raceid` varchar(50) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Dumping data for table origenv2qb.race_tracks: ~0 rows (approximately)

-- Dumping structure for table origenv2qb.randol_cs
CREATE TABLE IF NOT EXISTS `randol_cs` (
  `cid` varchar(100) NOT NULL,
  `tasksleft` int(10) NOT NULL,
  PRIMARY KEY (`cid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

-- Dumping data for table origenv2qb.randol_cs: ~0 rows (approximately)

-- Dumping structure for table origenv2qb.redeem
CREATE TABLE IF NOT EXISTS `redeem` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `license` varchar(50) DEFAULT NULL,
  `citizenid` varchar(50) DEFAULT NULL,
  `vehicle` varchar(50) DEFAULT NULL,
  `code` varchar(50) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=340 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Dumping data for table origenv2qb.redeem: ~0 rows (approximately)

-- Dumping structure for table origenv2qb.sprays
CREATE TABLE IF NOT EXISTS `sprays` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `x` float(8,4) NOT NULL,
  `y` float(8,4) NOT NULL,
  `z` float(8,4) NOT NULL,
  `rx` float(8,4) NOT NULL,
  `ry` float(8,4) NOT NULL,
  `rz` float(8,4) NOT NULL,
  `scale` float(8,4) NOT NULL,
  `text` varchar(32) NOT NULL,
  `font` varchar(32) NOT NULL,
  `color` int(3) NOT NULL,
  `interior` int(3) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

-- Dumping data for table origenv2qb.sprays: ~0 rows (approximately)

-- Dumping structure for table origenv2qb.stashitems
CREATE TABLE IF NOT EXISTS `stashitems` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `stash` varchar(255) NOT NULL DEFAULT '[]',
  `items` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL,
  PRIMARY KEY (`stash`),
  KEY `id` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=87 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Dumping data for table origenv2qb.stashitems: ~14 rows (approximately)
INSERT INTO `stashitems` (`id`, `stash`, `items`) VALUES
	(64, 'balcaouwu', '[]'),
	(79, 'DarkWebCrate_1', '[]'),
	(77, 'FishingBox_613', '[]'),
	(69, 'fridge', '[{"slot":1,"label":"Banana","weight":1000,"amount":1,"info":{"quality":100},"created":1718927702,"name":"banana","useable":true,"image":"banana.png","unique":false,"type":"item"},{"slot":2,"label":"Kiwi","weight":1000,"amount":1,"info":{"quality":100},"created":1718927703,"name":"kiwi","useable":true,"image":"kiwi.png","unique":false,"type":"item"},{"slot":3,"label":"Apple","weight":1000,"amount":1,"info":{"quality":100},"created":1718927697,"name":"apple","useable":true,"image":"apple.png","unique":false,"type":"item"},null,null,{"slot":6,"label":"Lemon","weight":1000,"amount":1,"info":{"quality":100},"created":1718927704,"name":"lemon","useable":true,"image":"lemon.png","unique":false,"type":"item"},{"slot":7,"label":"Glass","weight":1000,"amount":1,"info":{"quality":100},"created":1718927700,"name":"drink-glass","useable":true,"image":"drink-glass.png","unique":false,"type":"item"},null,null,null,{"slot":11,"label":"Watermelon","weight":1000,"amount":1,"info":{"quality":100},"created":1718927705,"name":"watermelon","useable":true,"image":"watermelon.png","unique":false,"type":"item"},{"slot":12,"label":"Strawberry Donut","weight":200,"amount":1,"info":{"quality":100},"created":1718927715,"name":"limeysdonut","useable":true,"image":"limeysdonut2.png","unique":false,"type":"item"}]'),
	(66, 'FrigorificoIngredientes', '[]'),
	(65, 'frigorificouwu', '[]'),
	(68, 'limeyscabinet1', '[]'),
	(60, 'mechanicSafe', '[]'),
	(84, 'policestash_ZEN90470', '[]'),
	(58, 'storge', '[]'),
	(63, 'TabuleiroUwU1', '[]'),
	(72, 'Teapot Counter', '[{"amount":30,"image":"ltstrawberry.png","name":"ltstrawberry","type":"item","label":"Strawberries","weight":10,"unique":false,"slot":1,"info":{"quality":100},"useable":false},{"amount":30,"image":"ltraspberry.png","name":"ltraspberry","type":"item","label":"Raspberries","weight":10,"unique":false,"slot":2,"info":{"quality":100},"useable":false}]'),
	(73, 'Teapot Stash', '[]'),
	(56, 'tray4', '[]');

-- Dumping structure for table origenv2qb.tinder_likes
CREATE TABLE IF NOT EXISTS `tinder_likes` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `phone` varchar(1024) NOT NULL,
  `likeds` mediumtext NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Dumping data for table origenv2qb.tinder_likes: ~0 rows (approximately)

-- Dumping structure for table origenv2qb.tinder_messages
CREATE TABLE IF NOT EXISTS `tinder_messages` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `phone` varchar(50) NOT NULL,
  `number` varchar(50) NOT NULL,
  `messages` varchar(1024) DEFAULT '{}',
  PRIMARY KEY (`id`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=11 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Dumping data for table origenv2qb.tinder_messages: ~0 rows (approximately)

-- Dumping structure for table origenv2qb.trucker_available_contracts
CREATE TABLE IF NOT EXISTS `trucker_available_contracts` (
  `contract_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `contract_type` bit(1) NOT NULL DEFAULT b'0',
  `contract_name` varchar(50) NOT NULL DEFAULT '',
  `coords_index` smallint(6) unsigned NOT NULL DEFAULT 0,
  `price_per_km` int(10) unsigned NOT NULL DEFAULT 0,
  `cargo_type` tinyint(3) unsigned NOT NULL DEFAULT 0,
  `fragile` bit(1) NOT NULL DEFAULT b'0',
  `valuable` bit(1) NOT NULL DEFAULT b'0',
  `fast` bit(1) NOT NULL DEFAULT b'0',
  `truck` varchar(50) DEFAULT NULL,
  `trailer` varchar(50) NOT NULL,
  PRIMARY KEY (`contract_id`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=6844 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Dumping data for table origenv2qb.trucker_available_contracts: ~0 rows (approximately)

-- Dumping structure for table origenv2qb.trucker_drivers
CREATE TABLE IF NOT EXISTS `trucker_drivers` (
  `driver_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` varchar(50) DEFAULT NULL,
  `name` varchar(50) NOT NULL DEFAULT '',
  `product_type` tinyint(3) unsigned NOT NULL DEFAULT 0,
  `distance` tinyint(3) unsigned NOT NULL DEFAULT 0,
  `valuable` tinyint(3) unsigned NOT NULL DEFAULT 0,
  `fragile` tinyint(3) unsigned NOT NULL DEFAULT 0,
  `fast` tinyint(3) unsigned NOT NULL DEFAULT 0,
  `price` int(10) unsigned NOT NULL DEFAULT 0,
  `price_per_km` int(10) unsigned NOT NULL DEFAULT 0,
  `img` varchar(50) DEFAULT NULL,
  PRIMARY KEY (`driver_id`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=377 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Dumping data for table origenv2qb.trucker_drivers: ~0 rows (approximately)

-- Dumping structure for table origenv2qb.trucker_loans
CREATE TABLE IF NOT EXISTS `trucker_loans` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` varchar(50) NOT NULL,
  `loan` int(10) unsigned NOT NULL DEFAULT 0,
  `remaining_amount` int(10) unsigned NOT NULL DEFAULT 0,
  `day_cost` int(10) unsigned NOT NULL DEFAULT 0,
  `taxes_on_day` int(10) unsigned NOT NULL DEFAULT 0,
  `timer` int(10) unsigned NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=12 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Dumping data for table origenv2qb.trucker_loans: ~0 rows (approximately)

-- Dumping structure for table origenv2qb.trucker_trucks
CREATE TABLE IF NOT EXISTS `trucker_trucks` (
  `truck_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` varchar(50) NOT NULL,
  `truck_name` varchar(50) NOT NULL,
  `driver` int(10) unsigned DEFAULT NULL,
  `body` smallint(5) unsigned NOT NULL DEFAULT 1000,
  `engine` smallint(5) unsigned NOT NULL DEFAULT 1000,
  `transmission` smallint(5) unsigned NOT NULL DEFAULT 1000,
  `wheels` smallint(5) unsigned NOT NULL DEFAULT 1000,
  PRIMARY KEY (`truck_id`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Dumping data for table origenv2qb.trucker_trucks: ~0 rows (approximately)

-- Dumping structure for table origenv2qb.trucker_users
CREATE TABLE IF NOT EXISTS `trucker_users` (
  `user_id` varchar(50) NOT NULL,
  `money` int(10) unsigned NOT NULL DEFAULT 0,
  `total_earned` int(10) unsigned NOT NULL DEFAULT 0,
  `finished_deliveries` int(10) unsigned NOT NULL DEFAULT 0,
  `exp` int(10) unsigned NOT NULL DEFAULT 0,
  `traveled_distance` double unsigned NOT NULL DEFAULT 0,
  `skill_points` int(10) unsigned NOT NULL DEFAULT 0,
  `product_type` tinyint(3) unsigned NOT NULL DEFAULT 0,
  `distance` tinyint(3) unsigned NOT NULL DEFAULT 0,
  `valuable` tinyint(3) unsigned NOT NULL DEFAULT 0,
  `fragile` tinyint(3) unsigned NOT NULL DEFAULT 0,
  `fast` tinyint(3) unsigned NOT NULL DEFAULT 0,
  `loan_notify` bit(1) NOT NULL DEFAULT b'0',
  PRIMARY KEY (`user_id`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Dumping data for table origenv2qb.trucker_users: ~0 rows (approximately)

-- Dumping structure for table origenv2qb.trunkitems
CREATE TABLE IF NOT EXISTS `trunkitems` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `plate` varchar(255) NOT NULL,
  `items` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL,
  PRIMARY KEY (`plate`),
  KEY `id` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

-- Dumping data for table origenv2qb.trunkitems: ~0 rows (approximately)

-- Dumping structure for table origenv2qb.twitter_account
CREATE TABLE IF NOT EXISTS `twitter_account` (
  `id` varchar(90) NOT NULL,
  `name` varchar(50) NOT NULL,
  `phone` varchar(50) NOT NULL,
  `username` varchar(50) NOT NULL,
  `password` varchar(50) NOT NULL,
  `avatar` text NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Dumping data for table origenv2qb.twitter_account: ~0 rows (approximately)

-- Dumping structure for table origenv2qb.twitter_hashtags
CREATE TABLE IF NOT EXISTS `twitter_hashtags` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(80) NOT NULL,
  `created` varchar(50) NOT NULL,
  `count` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=8 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Dumping data for table origenv2qb.twitter_hashtags: ~0 rows (approximately)

-- Dumping structure for table origenv2qb.twitter_mentions
CREATE TABLE IF NOT EXISTS `twitter_mentions` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `id_tweet` int(11) NOT NULL,
  `username` varchar(50) NOT NULL,
  `mentioned` text NOT NULL,
  `created` varchar(50) NOT NULL,
  PRIMARY KEY (`id`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Dumping data for table origenv2qb.twitter_mentions: ~0 rows (approximately)

-- Dumping structure for table origenv2qb.twitter_tweets
CREATE TABLE IF NOT EXISTS `twitter_tweets` (
  `id` int(5) NOT NULL AUTO_INCREMENT,
  `username` varchar(80) NOT NULL,
  `message` longtext NOT NULL,
  `hashtags` varchar(50) NOT NULL,
  `mentions` varchar(50) NOT NULL,
  `created` varchar(50) NOT NULL,
  `image` text NOT NULL,
  `likes` text DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=24 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Dumping data for table origenv2qb.twitter_tweets: ~0 rows (approximately)

-- Dumping structure for table origenv2qb.vehicle_trackers
CREATE TABLE IF NOT EXISTS `vehicle_trackers` (
  `serialNumber` varchar(11) NOT NULL,
  `vehiclePlate` varchar(11) NOT NULL,
  `startedAt` timestamp NOT NULL DEFAULT current_timestamp(),
  UNIQUE KEY `serialNumber` (`serialNumber`),
  KEY `vehiclePlate` (`vehiclePlate`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

-- Dumping data for table origenv2qb.vehicle_trackers: ~0 rows (approximately)

-- Dumping structure for table origenv2qb.whatsapp_accounts
CREATE TABLE IF NOT EXISTS `whatsapp_accounts` (
  `id` varchar(100) NOT NULL,
  `name` varchar(50) NOT NULL,
  `phone` varchar(50) NOT NULL,
  `password` varchar(50) NOT NULL,
  `avatar` text NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Dumping data for table origenv2qb.whatsapp_accounts: ~0 rows (approximately)

-- Dumping structure for table origenv2qb.whatsapp_chats
CREATE TABLE IF NOT EXISTS `whatsapp_chats` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `phone` varchar(50) NOT NULL,
  `number` varchar(50) NOT NULL,
  `created` varchar(50) NOT NULL,
  `messages` text NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=43 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Dumping data for table origenv2qb.whatsapp_chats: ~0 rows (approximately)

-- Dumping structure for table origenv2qb.whatsapp_groups
CREATE TABLE IF NOT EXISTS `whatsapp_groups` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `phone` varchar(50) NOT NULL,
  `number` varchar(50) NOT NULL,
  `type` varchar(50) NOT NULL,
  `name` varchar(50) NOT NULL,
  `image` text NOT NULL,
  `created` varchar(50) NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=8 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Dumping data for table origenv2qb.whatsapp_groups: ~0 rows (approximately)

-- Dumping structure for table origenv2qb.whatsapp_groups_messages
CREATE TABLE IF NOT EXISTS `whatsapp_groups_messages` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `id_group` varchar(50) NOT NULL,
  `owner` varchar(50) NOT NULL,
  `type` varchar(50) NOT NULL,
  `message` text NOT NULL,
  `created` varchar(50) NOT NULL,
  `read` int(11) NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Dumping data for table origenv2qb.whatsapp_groups_messages: ~0 rows (approximately)

-- Dumping structure for table origenv2qb.whatsapp_groups_users
CREATE TABLE IF NOT EXISTS `whatsapp_groups_users` (
  `number_group` varchar(50) NOT NULL,
  `admin` int(11) NOT NULL,
  `phone` varchar(50) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Dumping data for table origenv2qb.whatsapp_groups_users: ~0 rows (approximately)

-- Dumping structure for table origenv2qb.whatsapp_stories
CREATE TABLE IF NOT EXISTS `whatsapp_stories` (
  `phone` varchar(50) NOT NULL,
  `image` text NOT NULL,
  `created` varchar(50) NOT NULL,
  `description` varchar(50) DEFAULT NULL,
  `location` varchar(50) DEFAULT NULL,
  `filter` varchar(50) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Dumping data for table origenv2qb.whatsapp_stories: ~0 rows (approximately)

-- Dumping structure for table origenv2qb.yellowpages_posts
CREATE TABLE IF NOT EXISTS `yellowpages_posts` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `owner` text NOT NULL,
  `mesaj` text NOT NULL,
  `isim` text NOT NULL,
  `telno` text NOT NULL,
  `resim` text DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Dumping data for table origenv2qb.yellowpages_posts: ~0 rows (approximately)

/*!40103 SET TIME_ZONE=IFNULL(@OLD_TIME_ZONE, 'system') */;
/*!40101 SET SQL_MODE=IFNULL(@OLD_SQL_MODE, '') */;
/*!40014 SET FOREIGN_KEY_CHECKS=IFNULL(@OLD_FOREIGN_KEY_CHECKS, 1) */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40111 SET SQL_NOTES=IFNULL(@OLD_SQL_NOTES, 1) */;
