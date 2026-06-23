-- ============================================================================
--  server_setup.sql  --  State of Mind RP (QBCore / Origen V2, build 25770)
--  Consolidated & re-runnable database schema.
--  Generated from all per-resource .sql files + confirmed missing tables.
--
--  Structure:  (1) all CREATE TABLE IF NOT EXISTS   (2) all INSERT IGNORE seed data
--  Safe to import multiple times: no duplicate-key (#1062) or "table exists" errors.
-- ============================================================================

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;


-- ===== TABLES =====

-- table: accounts
CREATE TABLE IF NOT EXISTS `accounts` (
  `identifier` varchar(50) NOT NULL,
  `id` varchar(50) NOT NULL DEFAULT '',
  `name` longtext NOT NULL,
  `balance` bigint(20) NOT NULL DEFAULT 0,
  `transactions` longtext NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

-- table: addon_account
CREATE TABLE IF NOT EXISTS `addon_account` (
  `name` text DEFAULT NULL,
  `label` text DEFAULT NULL,
  `shared` text DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- table: apartments
CREATE TABLE IF NOT EXISTS `apartments` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(255) DEFAULT NULL,
  `type` varchar(255) DEFAULT NULL,
  `label` varchar(255) DEFAULT NULL,
  `citizenid` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `citizenid` (`citizenid`),
  KEY `name` (`name`)
) ENGINE=InnoDB AUTO_INCREMENT=4144 DEFAULT CHARSET=latin1;

-- table: bans
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
) ENGINE=InnoDB AUTO_INCREMENT=1;

-- table: crypto
CREATE TABLE IF NOT EXISTS `crypto` (
  `crypto` varchar(50) NOT NULL DEFAULT 'qbit',
  `worth` int(11) NOT NULL DEFAULT 0,
  `history` text DEFAULT NULL,
  PRIMARY KEY (`crypto`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- table: crypto_transactions
CREATE TABLE IF NOT EXISTS `crypto_transactions` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `citizenid` varchar(50) DEFAULT NULL,
  `title` varchar(50) DEFAULT NULL,
  `message` varchar(50) DEFAULT NULL,
  `date` timestamp NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `citizenid` (`citizenid`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4;

-- table: cryptominers
CREATE TABLE IF NOT EXISTS `cryptominers` (
    `citizenid` varchar(50) NOT NULL,
    `card` varchar(50) NOT NULL,
    `balance` double NOT NULL,
    PRIMARY KEY (`citizenid`)
);

-- table: datastore
CREATE TABLE IF NOT EXISTS `datastore` (
  `name` text DEFAULT NULL,
  `label` text DEFAULT NULL,
  `shared` text DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- table: dealers
CREATE TABLE IF NOT EXISTS `dealers` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(50) NOT NULL DEFAULT '0',
  `coords` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL,
  `time` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL,
  `createdby` varchar(50) NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=19 DEFAULT CHARSET=latin1;

-- table: debux_petshop
CREATE TABLE IF NOT EXISTS `debux_petshop` (
  `identifier` varchar(50) DEFAULT NULL,
  `pet_code` varchar(50) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- table: fuel_stations
CREATE TABLE IF NOT EXISTS `fuel_stations` (
  `location` int(11) DEFAULT NULL,
  `owned` int(11) DEFAULT NULL,
  `owner` varchar(50) DEFAULT NULL,
  `fuel` int(11) DEFAULT NULL,
  `fuelprice` int(11) DEFAULT NULL,
  `balance` int(255) DEFAULT NULL,
  `label` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`location`)
) ENGINE=InnoDB;

-- table: gloveboxitems
CREATE TABLE IF NOT EXISTS `gloveboxitems` (
  `plate` varchar(50) NOT NULL,
  `items` longtext DEFAULT NULL,
  PRIMARY KEY (`plate`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- table: house_plants
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
) ENGINE=InnoDB AUTO_INCREMENT=7123 DEFAULT CHARSET=utf8mb4;

-- table: houselocations
CREATE TABLE IF NOT EXISTS `houselocations` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(255) DEFAULT NULL,
  `label` varchar(255) DEFAULT NULL,
  `coords` text DEFAULT NULL,
  `owned` tinyint(2) DEFAULT NULL,
  `price` int(11) DEFAULT NULL,
  `tier` tinyint(4) DEFAULT NULL,
  `garage` text NOT NULL DEFAULT '{"y":0,"x":0,"h":0,"z":0}',
  PRIMARY KEY (`id`),
  KEY `name` (`name`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=latin1;

-- table: items
CREATE TABLE IF NOT EXISTS `items` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(100) NOT NULL,
  `label` varchar(100) NOT NULL,
  `weight` decimal(11,2) NOT NULL DEFAULT 0.00,
  `rare` int(11) NOT NULL DEFAULT 0,
  `can_remove` int(11) NOT NULL DEFAULT 1,
  `type` varchar(50) NOT NULL DEFAULT 'item',
  `unique` varchar(10) DEFAULT 'false',
  `description` text DEFAULT NULL,
  `image` varchar(100) DEFAULT NULL,
  `shouldClose` int(11) DEFAULT 0,
  `combinable` text DEFAULT NULL,
  PRIMARY KEY (`name`),
  UNIQUE KEY `id` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- table: job_grades
CREATE TABLE IF NOT EXISTS `job_grades` (
  `job_name` text DEFAULT NULL,
  `grade` text DEFAULT NULL,
  `name` text DEFAULT NULL,
  `label` text DEFAULT NULL,
  `salary` text DEFAULT NULL,
  `skin_male` text DEFAULT NULL,
  `skin_female` text DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- table: jobs
CREATE TABLE IF NOT EXISTS `jobs` (
  `name` text DEFAULT NULL,
  `label` text DEFAULT NULL,
  `whitelisted` text DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- table: lapraces
CREATE TABLE IF NOT EXISTS `lapraces` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(50) DEFAULT NULL,
  `checkpoints` text DEFAULT NULL,
  `records` text DEFAULT NULL,
  `creator` varchar(50) DEFAULT NULL,
  `distance` int(11) DEFAULT NULL,
  `raceid` varchar(50) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=35 DEFAULT CHARSET=utf8mb4;

-- table: management_funds
CREATE TABLE IF NOT EXISTS `management_funds` (
`id` INT(11) NOT NULL AUTO_INCREMENT,
`job_name` VARCHAR(50) NOT NULL,
`amount`  INT(100) NOT NULL,
`type` ENUM('boss','gang') NOT NULL DEFAULT 'boss',
PRIMARY KEY (`id`),
UNIQUE KEY `job_name` (`job_name`),
KEY `type` (`type`)
);

-- table: mdt_config
CREATE TABLE IF NOT EXISTS `mdt_config` (
  `citizenid` VARCHAR(10) NOT NULL,
  `theme` int(11) NOT NULL,
  `sidebar` int(11) NOT NULL,
  UNIQUE KEY `citizenid` (`citizenid`) USING HASH
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- table: mdt_evidences
CREATE TABLE IF NOT EXISTS `mdt_evidences` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `imgurl` text NOT NULL,
  `description` text NOT NULL,
  `type` text NOT NULL,
  `date` text NOT NULL,
  `createdby` text NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=latin1;

-- table: mdt_incidents
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
) ENGINE=InnoDB AUTO_INCREMENT=6 DEFAULT CHARSET=latin1;

-- table: mdt_profiles
CREATE TABLE IF NOT EXISTS `mdt_profiles` (
  `citizenid` VARCHAR(10) NOT NULL,
  `notes` text NOT NULL,
  `image` text NOT NULL,
  UNIQUE KEY `citizenid` (`citizenid`) USING HASH
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- table: mdt_reports
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
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=latin1;

-- table: mdt_vehicles
CREATE TABLE IF NOT EXISTS `mdt_vehicles` (
  `plate` VARCHAR(10) NOT NULL,
  `image` text NOT NULL,
  `notes` text NOT NULL,
  UNIQUE KEY `plate` (`plate`) USING HASH
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- table: mdt_warrants
CREATE TABLE IF NOT EXISTS `mdt_warrants` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `incident` int(11) NOT NULL,
  `citizenid` text NOT NULL,
  `date` text NOT NULL,
  `approved` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=latin1;

-- table: ox_doorlock
CREATE TABLE
    IF NOT EXISTS `ox_doorlock` (
        `id` int (11) unsigned NOT NULL AUTO_INCREMENT,
        `name` varchar(50) NOT NULL,
        `data` longtext NOT NULL,
        PRIMARY KEY (`id`)
    );

-- table: phone_gallery
CREATE TABLE IF NOT EXISTS `phone_gallery` (
   `citizenid` VARCHAR(255) NOT NULL , 
   `image` VARCHAR(255) NOT NULL ,
   `date` timestamp NULL DEFAULT current_timestamp()
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4;

-- table: phone_invoices
CREATE TABLE IF NOT EXISTS `phone_invoices` (
  `id` int(10) NOT NULL AUTO_INCREMENT,
  `citizenid` varchar(50) DEFAULT NULL,
  `amount` int(11) NOT NULL DEFAULT 0,
  `society` tinytext DEFAULT NULL,
  `sender` varchar(50) DEFAULT NULL,
  `sendercitizenid` varchar(50) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `citizenid` (`citizenid`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4;

-- table: phone_messages
CREATE TABLE IF NOT EXISTS `phone_messages` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `citizenid` varchar(50) DEFAULT NULL,
  `number` varchar(50) DEFAULT NULL,
  `messages` text DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `citizenid` (`citizenid`),
  KEY `number` (`number`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4;

-- table: phone_tweets
CREATE TABLE IF NOT EXISTS `phone_tweets` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `citizenid` varchar(50) DEFAULT NULL,
  `firstName` varchar(25) DEFAULT NULL,
  `lastName` varchar(25) DEFAULT NULL,
  `message` text DEFAULT NULL,
  `date` datetime DEFAULT current_timestamp(),
  `url` text DEFAULT NULL,
  `picture` text DEFAULT './img/default.png',
  `tweetId` varchar(25) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `citizenid` (`citizenid`)
) ENGINE=InnoDB AUTO_INCREMENT=1;

-- table: player_contacts
CREATE TABLE IF NOT EXISTS `player_contacts` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `citizenid` varchar(50) DEFAULT NULL,
  `name` varchar(50) DEFAULT NULL,
  `number` varchar(50) DEFAULT NULL,
  `iban` varchar(50) NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  KEY `citizenid` (`citizenid`)
) ENGINE=InnoDB AUTO_INCREMENT=1;

-- table: player_houses
CREATE TABLE IF NOT EXISTS `player_houses` (
  `id` int(255) NOT NULL AUTO_INCREMENT,
  `house` varchar(50) NOT NULL,
  `identifier` varchar(50) DEFAULT NULL,
  `citizenid` varchar(50) DEFAULT NULL,
  `keyholders` text DEFAULT NULL,
  `decorations` text DEFAULT NULL,
  `stash` text DEFAULT NULL,
  `outfit` text DEFAULT NULL,
  `logout` text DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `house` (`house`),
  KEY `citizenid` (`citizenid`),
  KEY `identifier` (`identifier`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4;

-- table: player_mails
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
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4;

-- table: player_outfits
CREATE TABLE IF NOT EXISTS `player_outfits` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `citizenid` varchar(50) DEFAULT NULL,
  `outfitname` varchar(50) NOT NULL,
  `model` varchar(50) DEFAULT NULL,
  `skin` text DEFAULT NULL,
  `outfitId` varchar(50) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `citizenid` (`citizenid`),
  KEY `outfitId` (`outfitId`)
) ENGINE=InnoDB AUTO_INCREMENT=8970 DEFAULT CHARSET=utf8mb4;

-- table: player_vehicles
CREATE TABLE IF NOT EXISTS `player_vehicles` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `license` varchar(50) DEFAULT NULL,
  `citizenid` varchar(50) DEFAULT NULL,
  `vehicle` varchar(50) DEFAULT NULL,
  `hash` varchar(50) DEFAULT NULL,
  `mods` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL,
  `plate` varchar(50) NOT NULL,
  `fakeplate` varchar(50) DEFAULT NULL,
  `garage` varchar(50) DEFAULT NULL,
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
  PRIMARY KEY (`id`),
  KEY `plate` (`plate`),
  KEY `citizenid` (`citizenid`),
  KEY `license` (`license`)
) ENGINE=InnoDB AUTO_INCREMENT=1;

-- table: player_warns
CREATE TABLE IF NOT EXISTS `player_warns` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `senderIdentifier` varchar(50) DEFAULT NULL,
  `targetIdentifier` varchar(50) DEFAULT NULL,
  `reason` text DEFAULT NULL,
  `warnId` varchar(50) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- table: players
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
  PRIMARY KEY (`citizenid`),
  KEY `id` (`id`),
  KEY `last_updated` (`last_updated`),
  KEY `license` (`license`)
) ENGINE=InnoDB AUTO_INCREMENT=1;

-- table: playerskins
CREATE TABLE IF NOT EXISTS `playerskins` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `citizenid` varchar(255) NOT NULL,
  `model` varchar(255) NOT NULL,
  `skin` text NOT NULL,
  `active` tinyint(2) NOT NULL DEFAULT 1,
  PRIMARY KEY (`id`),
  KEY `citizenid` (`citizenid`),
  KEY `active` (`active`)
) ENGINE=InnoDB AUTO_INCREMENT=43010 DEFAULT CHARSET=latin1;

-- table: punchmachine
CREATE TABLE IF NOT EXISTS `punchmachine` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(50) DEFAULT NULL,
  `score` varchar(50) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=655 DEFAULT CHARSET=utf8mb4;

-- table: randol_cs
CREATE TABLE IF NOT EXISTS randol_cs (
	cid VARCHAR(100) NOT NULL,
	tasksleft int(10) NOT NULL,
	PRIMARY KEY (cid)
);

-- table: sprays
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
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- table: stashitems
CREATE TABLE IF NOT EXISTS `stashitems` (
  `stash` varchar(100) NOT NULL,
  `items` longtext DEFAULT NULL,
  PRIMARY KEY (`stash`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- table: trunkitems
CREATE TABLE IF NOT EXISTS `trunkitems` (
  `plate` varchar(50) NOT NULL,
  `items` longtext DEFAULT NULL,
  PRIMARY KEY (`plate`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- table: vehicle_trackers
CREATE TABLE IF NOT EXISTS `vehicle_trackers` (
    `serialNumber` varchar(11) NOT NULL,
    `vehiclePlate` varchar(11) NOT NULL,
    `startedAt` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY `serialNumber` (`serialNumber`),
    KEY `vehiclePlate` (`vehiclePlate`)
);


-- ===== SEED DATA (INSERT IGNORE) =====

INSERT IGNORE INTO `debux_petshop` (`identifier`, `pet_code`) VALUES
	('steam:110000141678932', '2'),
	('2', '2'),
	('steam:110000141678932', 'a_c_rottweiler');

INSERT IGNORE INTO `ox_doorlock` (`id`, `name`, `data`) VALUES
	(1, 'community_mrpd 1', '{"coords":{"x":434.7478942871094,"y":-981.916748046875,"z":30.83926963806152},"groups":{"police":0,"offpolice":0},"maxDistance":2.5,"state":0,"doors":[{"coords":{"x":434.7478942871094,"y":-980.618408203125,"z":30.83926963806152},"model":-1215222675,"heading":270},{"coords":{"x":434.7478942871094,"y":-983.215087890625,"z":30.83926963806152},"model":320433149,"heading":270}],"hideUi":false}'),
	(2, 'community_mrpd 2', '{"coords":{"x":468.6697998046875,"y":-1014.4520263671875,"z":26.53623962402343},"groups":{"police":0},"maxDistance":2.5,"state":1,"doors":[{"coords":{"x":469.9679870605469,"y":-1014.4520263671875,"z":26.53623962402343},"model":-2023754432,"heading":180},{"coords":{"x":467.3716125488281,"y":-1014.4520263671875,"z":26.53623962402343},"model":-2023754432,"heading":0}],"hideUi":false}'),
	(3, 'community_mrpd 3', '{"coords":{"x":463.4783020019531,"y":-1003.5380249023438,"z":25.00598907470703},"model":-1033001619,"groups":{"police":0},"heading":0,"maxDistance":2,"state":1,"hideUi":false}'),
	(4, 'community_mrpd 4', '{"coords":{"x":488.8948059082031,"y":-1017.2100219726563,"z":27.14863014221191},"auto":true,"lockSound":"button-remote","groups":{"police":0},"heading":90,"maxDistance":5,"state":1,"model":-1603817716,"hideUi":false}'),
	(5, 'community_mrpd 5', '{"coords":{"x":431.4056091308594,"y":-1001.1690063476563,"z":26.71261024475097},"auto":true,"lockSound":"button-remote","groups":{"police":0},"heading":0,"maxDistance":5,"state":1,"model":-190780785,"hideUi":false}'),
	(6, 'community_mrpd 6', '{"coords":{"x":436.223388671875,"y":-1001.1690063476563,"z":26.71261024475097},"auto":true,"lockSound":"button-remote","groups":{"police":0},"heading":0,"maxDistance":5,"state":1,"model":-190780785,"hideUi":false}'),
	(7, 'community_mrpd 7', '{"coords":{"x":450.10418701171877,"y":-985.7384033203125,"z":30.83930969238281},"model":1557126584,"groups":{"police":0,"offpolice":0},"heading":90,"maxDistance":2,"state":1,"hideUi":false}'),
	(8, 'community_mrpd 8', '{"coords":{"x":464.15838623046877,"y":-1011.260009765625,"z":33.01121139526367},"model":507213820,"groups":{"police":0},"heading":0,"maxDistance":2,"state":1,"hideUi":false}'),
	(9, 'community_mrpd 9', '{"coords":{"x":461.2864990234375,"y":-985.3206176757813,"z":30.83926963806152},"model":749848321,"groups":{"police":0},"heading":90,"maxDistance":2,"state":1,"hideUi":false}'),
	(10, 'community_mrpd 10', '{"coords":{"x":446.57281494140627,"y":-980.0106201171875,"z":30.83930969238281},"model":-1320876379,"groups":{"police":0},"heading":180,"maxDistance":2,"state":1,"hideUi":false}'),
	(11, 'community_mrpd 11', '{"coords":{"x":453.09381103515627,"y":-983.2293701171875,"z":30.83926963806152},"model":-1033001619,"groups":{"police":0},"heading":91,"maxDistance":2,"state":1,"hideUi":false}'),
	(12, 'community_mrpd 12', '{"coords":{"x":464.36138916015627,"y":-984.677978515625,"z":43.83443832397461},"model":-340230128,"groups":{"police":0},"heading":90,"maxDistance":2,"state":1,"hideUi":false}'),
	(13, 'community_mrpd 13', '{"coords":{"x":442.6625061035156,"y":-988.2412719726563,"z":26.81977081298828},"model":-131296141,"groups":{"police":0},"heading":179,"maxDistance":2,"state":1,"hideUi":false}'),
	(14, 'community_mrpd 14', '{"coords":{"x":471.3153991699219,"y":-986.1090698242188,"z":25.05794906616211},"model":-131296141,"groups":{"police":0},"heading":270,"maxDistance":2,"state":1,"hideUi":false}'),
	(15, 'community_mrpd 15', '{"coords":{"x":467.5935974121094,"y":-977.9932861328125,"z":25.05794906616211},"model":-131296141,"groups":{"police":0},"heading":180,"maxDistance":2,"state":1,"hideUi":false}'),
	(16, 'community_mrpd 16', '{"coords":{"x":463.6145935058594,"y":-980.5814208984375,"z":25.05794906616211},"model":-131296141,"groups":{"police":0},"heading":90,"maxDistance":2,"state":1,"hideUi":false}'),
	(17, 'community_mrpd 17', '{"coords":{"x":464.5701904296875,"y":-992.6641235351563,"z":25.0644302368164},"model":631614199,"lockSound":"metal-locker","groups":{"police":0},"heading":0,"maxDistance":2,"state":1,"unlockSound":"metallic-creak","hideUi":false}'),
	(18, 'community_mrpd 18', '{"coords":{"x":461.8064880371094,"y":-994.4086303710938,"z":25.0644302368164},"model":631614199,"lockSound":"metal-locker","groups":{"police":0},"heading":270,"maxDistance":2,"state":1,"unlockSound":"metallic-creak","hideUi":false}'),
	(19, 'community_mrpd 19', '{"coords":{"x":461.8064880371094,"y":-997.6583862304688,"z":25.0644302368164},"model":631614199,"lockSound":"metal-locker","groups":{"police":0},"heading":90,"maxDistance":2,"state":1,"unlockSound":"metallic-creak","hideUi":false}'),
	(20, 'community_mrpd 20', '{"coords":{"x":461.8064880371094,"y":-1001.302001953125,"z":25.0644302368164},"model":631614199,"lockSound":"metal-locker","groups":{"police":0},"heading":90,"maxDistance":2,"state":1,"unlockSound":"metallic-creak","hideUi":false}'),
	(21, 'community_mrpd 21', '{"coords":{"x":467.19219970703127,"y":-996.4594116210938,"z":25.00598907470703},"model":-1033001619,"groups":{"police":0},"heading":0,"maxDistance":2,"state":1,"hideUi":false}'),
	(22, 'community_mrpd 22', '{"coords":{"x":471.4754943847656,"y":-996.4594116210938,"z":25.00598907470703},"model":-1033001619,"groups":{"police":0},"heading":0,"maxDistance":2,"state":1,"hideUi":false}'),
	(23, 'community_mrpd 23', '{"coords":{"x":475.7543029785156,"y":-996.4594116210938,"z":25.00598907470703},"model":-1033001619,"groups":{"police":0},"heading":0,"maxDistance":2,"state":1,"hideUi":false}'),
	(24, 'community_mrpd 24', '{"coords":{"x":480.03009033203127,"y":-996.4594116210938,"z":25.00598907470703},"model":-1033001619,"groups":{"police":0},"heading":0,"maxDistance":2,"state":1,"hideUi":false}'),
	(25, 'community_mrpd 25', '{"coords":{"x":468.4872131347656,"y":-1003.5479736328125,"z":25.01313972473144},"model":-1033001619,"groups":{"police":0},"heading":180,"maxDistance":2,"state":1,"hideUi":false}'),
	(26, 'community_mrpd 26', '{"coords":{"x":471.4747009277344,"y":-1003.5380249023438,"z":25.01222991943359},"model":-1033001619,"groups":{"police":0},"heading":0,"maxDistance":2,"state":1,"hideUi":false}'),
	(27, 'community_mrpd 27', '{"coords":{"x":477.0495910644531,"y":-1003.552001953125,"z":25.01203918457031},"auto":false,"groups":{"police":0},"heading":179,"lockpick":false,"maxDistance":2,"state":1,"model":-1033001619,"hideUi":false}'),
	(28, 'community_mrpd 28', '{"coords":{"x":480.03009033203127,"y":-1003.5380249023438,"z":25.00598907470703},"model":-1033001619,"groups":{"police":0},"heading":0,"maxDistance":2,"state":1,"hideUi":false}'),
	(29, 'community_mrpd 29', '{"coords":{"x":444.7078857421875,"y":-989.4453735351563,"z":30.83930969238281},"groups":{"police":0},"maxDistance":2.5,"state":1,"doors":[{"coords":{"x":443.4078063964844,"y":-989.4453735351563,"z":30.83930969238281},"model":185711165,"heading":180},{"coords":{"x":446.00799560546877,"y":-989.4453735351563,"z":30.83930969238281},"model":185711165,"heading":0}],"hideUi":false}'),
	(30, 'community_mrpd 30', '{"coords":{"x":445.9197998046875,"y":-999.0016479492188,"z":30.7890396118164},"groups":{"police":0},"maxDistance":2.5,"state":1,"doors":[{"coords":{"x":447.2184143066406,"y":-999.0023193359375,"z":30.78941917419433},"model":-1033001619,"heading":180},{"coords":{"x":444.6211853027344,"y":-999.0009765625,"z":30.78866004943847},"model":-1033001619,"heading":0}],"hideUi":false}'),
	(31, 'community_mrpd 31', '{"coords":{"x":445.9298400878906,"y":-997.044677734375,"z":30.84351921081543},"groups":{"police":0},"maxDistance":2.5,"state":0,"doors":[{"coords":{"x":444.62939453125,"y":-997.044677734375,"z":30.84351921081543},"model":-2023754432,"heading":0},{"coords":{"x":447.23028564453127,"y":-997.044677734375,"z":30.84351921081543},"model":-2023754432,"heading":180}],"hideUi":false}');

INSERT IGNORE INTO `ox_doorlock` (`id`, `name`, `data`) VALUES
	(1, 'mrpd locker rooms', '{"maxDistance":2,"heading":90,"coords":{"x":450.1041259765625,"y":-985.7384033203125,"z":30.83930206298828},"groups":{"police":0},"state":1,"model":1557126584,"hideUi":false}'),
	(2, 'mrpd cells/briefing', '{"maxDistance":2,"coords":{"x":444.7078552246094,"y":-989.4454345703125,"z":30.83930206298828},"doors":[{"model":185711165,"coords":{"x":446.0079345703125,"y":-989.4454345703125,"z":30.83930206298828},"heading":0},{"model":185711165,"coords":{"x":443.40777587890627,"y":-989.4454345703125,"z":30.83930206298828},"heading":180}],"groups":{"police":0},"state":1,"hideUi":false}'),
	(3, 'mrpd cell 3', '{"maxDistance":2,"heading":90,"coords":{"x":461.8065185546875,"y":-1001.9515380859375,"z":25.06442832946777},"lockSound":"metal-locker","groups":{"police":0},"state":1,"unlockSound":"metallic-creak","model":631614199,"hideUi":false}'),
	(4, 'mrpd back entrance', '{"maxDistance":2,"coords":{"x":468.6697692871094,"y":-1014.4520263671875,"z":26.5362319946289},"doors":[{"model":-2023754432,"coords":{"x":467.37164306640627,"y":-1014.4520263671875,"z":26.5362319946289},"heading":0},{"model":-2023754432,"coords":{"x":469.9678955078125,"y":-1014.4520263671875,"z":26.5362319946289},"heading":180}],"groups":{"police":0},"state":1,"hideUi":false}'),
	(5, 'mrpd cells security door', '{"maxDistance":2,"heading":0,"coords":{"x":464.1282958984375,"y":-1003.5386962890625,"z":25.00598907470703},"autolock":5,"groups":{"police":0},"state":1,"model":-1033001619,"hideUi":false}'),
	(6, 'mrpd cell 2', '{"maxDistance":2,"heading":90,"coords":{"x":461.8064880371094,"y":-998.3082885742188,"z":25.06442832946777},"lockSound":"metal-locker","groups":{"police":0},"state":1,"unlockSound":"metallic-creak","model":631614199,"hideUi":false}'),
	(7, 'mrpd captain\'s office', '{"maxDistance":2,"heading":180,"coords":{"x":446.57281494140627,"y":-980.0105590820313,"z":30.83930206298828},"groups":{"police":0},"state":1,"model":-1320876379,"hideUi":false}'),
	(8, 'mrpd gate', '{"maxDistance":6,"heading":90,"coords":{"x":488.894775390625,"y":-1017.2102661132813,"z":27.14714050292968},"groups":{"police":0},"auto":true,"state":1,"model":-1603817716,"hideUi":false}'),
	(9, 'mrpd cell 1', '{"maxDistance":2,"heading":270,"coords":{"x":461.8065185546875,"y":-993.7586059570313,"z":25.06442832946777},"lockSound":"metal-locker","groups":{"police":0},"state":1,"unlockSound":"metallic-creak","model":631614199,"hideUi":false}'),
	(10, 'mrpd cells main', '{"maxDistance":2,"heading":360,"coords":{"x":463.92010498046877,"y":-992.6640625,"z":25.06442832946777},"lockSound":"metal-locker","groups":{"police":0},"state":1,"unlockSound":"metallic-creak","model":631614199,"hideUi":false}'),
	(11, 'mrpd armoury', '{"maxDistance":2,"heading":270,"coords":{"x":453.08428955078127,"y":-982.5794677734375,"z":30.81926536560058},"autolock":5,"groups":{"police":0},"state":1,"model":749848321,"hideUi":false}');;

INSERT IGNORE INTO `items` (`name`, `label`, `weight`, `rare`, `can_remove`, `type`, `unique`, `description`, `image`, `shouldClose`, `combinable`, `id`) VALUES ('forceps', 'forceps', '0.01', '0', '1', 'item', 'false', 'Bilinmiyor', 'forceps.png', '0', NULL, NULL);

INSERT IGNORE INTO `items` (`name`, `label`, `weight`, `rare`, `can_remove`, `type`, `unique`, `description`, `image`, `shouldClose`, `combinable`, `id`) VALUES ('gauze', 'gauze', '0.01', '0', '1', 'item', 'false', 'Bilinmiyor', 'gauze.png', '0', NULL, NULL);

INSERT IGNORE INTO `items` (`name`, `label`, `weight`, `rare`, `can_remove`, `type`, `unique`, `description`, `image`, `shouldClose`, `combinable`, `id`) VALUES ('iodine', 'iodine', '0.01', '0', '1', 'item', 'false', 'Bilinmiyor', 'iodine.png', '0', NULL, NULL);

INSERT IGNORE INTO `items` (`name`, `label`, `weight`, `rare`, `can_remove`, `type`, `unique`, `description`, `image`, `shouldClose`, `combinable`, `id`) VALUES ('pill', 'pill', '0.01', '0', '1', 'item', 'false', 'Bilinmiyor', 'pill.png', '0', NULL, NULL);

INSERT IGNORE INTO `items` (`name`, `label`, `weight`, `rare`, `can_remove`, `type`, `unique`, `description`, `image`, `shouldClose`, `combinable`, `id`) VALUES ('surgical_gloves', 'surgical_gloves', '0.01', '0', '1', 'item', 'false', 'Bilinmiyor', 'surgical-gloves.png', '0', NULL, NULL);

INSERT IGNORE INTO `items` (`name`, `label`, `weight`, `rare`, `can_remove`, `type`, `unique`, `description`, `image`, `shouldClose`, `combinable`, `id`) VALUES ('surgical_staple', 'surgical_staple', '0.01', '0', '1', 'item', 'false', 'Bilinmiyor', 'surgical-staple.png', '0', NULL, NULL);

INSERT IGNORE INTO `items` (`name`, `label`, `weight`, `rare`, `can_remove`, `type`, `unique`, `description`, `image`, `shouldClose`, `combinable`, `id`) VALUES ('surgical_tray', 'surgical_tray', '0.01', '0', '1', 'item', 'false', 'Bilinmiyor', 'surgical-tray.png', '0', NULL, NULL);

INSERT IGNORE INTO `items` (`name`, `label`, `weight`, `rare`, `can_remove`, `type`, `unique`, `description`, `image`, `shouldClose`, `combinable`, `id`) VALUES ('syringe', 'syringe', '0.01', '0', '1', 'item', 'false', 'Bilinmiyor', 'syringe.png', '0', NULL, NULL);

INSERT IGNORE INTO `items` (`name`, `label`, `weight`, `rare`, `can_remove`, `type`, `unique`, `description`, `image`, `shouldClose`, `combinable`, `id`) VALUES ('tape', 'tape', '0.01', '0', '1', 'item', 'false', 'Bilinmiyor', 'tape.png', '0', NULL, NULL);

INSERT IGNORE INTO `items` (`name`, `label`, `weight`, `rare`, `can_remove`) VALUES ('bandageg', 'Bandage Gauze', '2', '0', '1');

INSERT IGNORE INTO `items` (`name`, `label`, `weight`, `rare`, `can_remove`) VALUES ('forceps', 'Forceps', '1', '0', '1'), ('gauze', 'Gauze', '1', '0', '1'), ('iodine', 'Iodine', '1', '0', '1'), ('pill', 'Pill', '1', '0', '1'), ('surgical_gloves', 'Surgical gloves', '1', '0', '1'), ('surgical_staple', 'Surgical staple', '1', '0', '1'), ('surgical_tray', 'Surgical tray', '1', '0', '1'), ('syringe', 'Syringe', '1', '0', '1'), ('tape', 'Tape', '1', '0', '1');

INSERT IGNORE INTO `jobs` (`name`, `label`, `whitelisted`) VALUES ('taxi', 'Taxi Company', '1');

INSERT IGNORE INTO `job_grades` (`job_name`, `grade`, `name`, `label`, `salary`, `skin_male`, `skin_female`) VALUES ('taxi', '0', 'recruit', 'Recruit', '0', '{}', '{}');

INSERT IGNORE INTO `job_grades` (`job_name`, `grade`, `name`, `label`, `salary`, `skin_male`, `skin_female`) VALUES ('taxi', '0', 'employee', 'Driver', '0', '{}', '{}');

INSERT IGNORE INTO `job_grades` (`job_name`, `grade`, `name`, `label`, `salary`, `skin_male`, `skin_female`) VALUES ('taxi', '0', 'manager', 'Lead Driver', '0', '{}', '{}');

INSERT IGNORE INTO `job_grades` (`job_name`, `grade`, `name`, `label`, `salary`, `skin_male`, `skin_female`) VALUES ('taxi', '0', 'boss', 'Owner', '0', '{}', '{}');

INSERT IGNORE INTO `addon_account` (name, label, shared) VALUES
    ('society_taxi', 'Taxi Company', 1);

INSERT IGNORE INTO `datastore` (name, label, shared) VALUES 
	('society_taxi', 'Taxi Company',1);

INSERT IGNORE INTO `crypto` VALUES ('qbit', 1000, '[{"NewWorth":1000,"PreviousWorth":1000}]');

INSERT IGNORE INTO `management_funds` (`job_name`, `amount`, `type`) VALUES
('police', 0, 'boss'),
('ambulance', 0, 'boss'),
('realestate', 0, 'boss'),
('taxi', 0, 'boss'),
('cardealer', 0, 'boss'),
('mechanic', 0, 'boss'),
('lostmc', 0, 'gang'),
('ballas', 0, 'gang'),
('vagos', 0, 'gang'),
('cartel', 0, 'gang'),
('families', 0, 'gang'),
('triads', 0, 'gang');

INSERT IGNORE INTO `fuel_stations` (`location`, `owned`, `owner`, `fuel`, `fuelprice`, `balance`, `label`) VALUES (1, 0, '0', 100000, 3, 0, 'Davis Avenue Ron');

INSERT IGNORE INTO `fuel_stations` (`location`, `owned`, `owner`, `fuel`, `fuelprice`, `balance`, `label`) VALUES (2, 0, '0', 100000, 3, 0, 'Grove Street LTD');

INSERT IGNORE INTO `fuel_stations` (`location`, `owned`, `owner`, `fuel`, `fuelprice`, `balance`, `label`) VALUES (3, 0, '0', 100000, 3, 0, 'Dutch London Xero');

INSERT IGNORE INTO `fuel_stations` (`location`, `owned`, `owner`, `fuel`, `fuelprice`, `balance`, `label`) VALUES (4, 0, '0', 100000, 3, 0, 'Little Seoul LTD');

INSERT IGNORE INTO `fuel_stations` (`location`, `owned`, `owner`, `fuel`, `fuelprice`, `balance`, `label`) VALUES (5, 0, '0', 100000, 3, 0, 'Strawberry Ave Xero');

INSERT IGNORE INTO `fuel_stations` (`location`, `owned`, `owner`, `fuel`, `fuelprice`, `balance`, `label`) VALUES (6, 0, '0', 100000, 3, 0, 'Popular Street Ron');

INSERT IGNORE INTO `fuel_stations` (`location`, `owned`, `owner`, `fuel`, `fuelprice`, `balance`, `label`) VALUES (7, 0, '0', 100000, 3, 0, 'Capital Blvd Ron');

INSERT IGNORE INTO `fuel_stations` (`location`, `owned`, `owner`, `fuel`, `fuelprice`, `balance`, `label`) VALUES (8, 0, '0', 100000, 3, 0, 'Mirror Park LTD');

INSERT IGNORE INTO `fuel_stations` (`location`, `owned`, `owner`, `fuel`, `fuelprice`, `balance`, `label`) VALUES (9, 0, '0', 100000, 3, 0, 'Clinton Ave Globe Oil');

INSERT IGNORE INTO `fuel_stations` (`location`, `owned`, `owner`, `fuel`, `fuelprice`, `balance`, `label`) VALUES (10, 0, '0', 100000, 3, 0, 'North Rockford Ron');

INSERT IGNORE INTO `fuel_stations` (`location`, `owned`, `owner`, `fuel`, `fuelprice`, `balance`, `label`) VALUES (11, 0, '0', 100000, 3, 0, 'Great Ocean Xero');

INSERT IGNORE INTO `fuel_stations` (`location`, `owned`, `owner`, `fuel`, `fuelprice`, `balance`, `label`) VALUES (12, 0, '0', 100000, 3, 0, 'Paleto Blvd Xero');

INSERT IGNORE INTO `fuel_stations` (`location`, `owned`, `owner`, `fuel`, `fuelprice`, `balance`, `label`) VALUES (13, 0, '0', 100000, 3, 0, 'Paleto Ron');

INSERT IGNORE INTO `fuel_stations` (`location`, `owned`, `owner`, `fuel`, `fuelprice`, `balance`, `label`) VALUES (14, 0, '0', 100000, 3, 0, 'Paleto Globe Oil');

INSERT IGNORE INTO `fuel_stations` (`location`, `owned`, `owner`, `fuel`, `fuelprice`, `balance`, `label`) VALUES (15, 0, '0', 100000, 3, 0, 'Grapeseed LTD');

INSERT IGNORE INTO `fuel_stations` (`location`, `owned`, `owner`, `fuel`, `fuelprice`, `balance`, `label`) VALUES (16, 0, '0', 100000, 3, 0, 'Sandy Shores Xero');

INSERT IGNORE INTO `fuel_stations` (`location`, `owned`, `owner`, `fuel`, `fuelprice`, `balance`, `label`) VALUES (17, 0, '0', 100000, 3, 0, 'Sandy Shores Globe Oil');

INSERT IGNORE INTO `fuel_stations` (`location`, `owned`, `owner`, `fuel`, `fuelprice`, `balance`, `label`) VALUES (18, 0, '0', 100000, 3, 0, 'Senora Freeway Xero');

INSERT IGNORE INTO `fuel_stations` (`location`, `owned`, `owner`, `fuel`, `fuelprice`, `balance`, `label`) VALUES (19, 0, '0', 100000, 3, 0, 'Harmony Globe Oil');

INSERT IGNORE INTO `fuel_stations` (`location`, `owned`, `owner`, `fuel`, `fuelprice`, `balance`, `label`) VALUES (20, 0, '0', 100000, 3, 0, 'Route 68 Globe Oil');

INSERT IGNORE INTO `fuel_stations` (`location`, `owned`, `owner`, `fuel`, `fuelprice`, `balance`, `label`) VALUES (21, 0, '0', 100000, 3, 0, 'Route 68 Workshop Globe O');

INSERT IGNORE INTO `fuel_stations` (`location`, `owned`, `owner`, `fuel`, `fuelprice`, `balance`, `label`) VALUES (22, 0, '0', 100000, 3, 0, 'Route 68 Xero');

INSERT IGNORE INTO `fuel_stations` (`location`, `owned`, `owner`, `fuel`, `fuelprice`, `balance`, `label`) VALUES (23, 0, '0', 100000, 3, 0, 'Route 68 Ron');

INSERT IGNORE INTO `fuel_stations` (`location`, `owned`, `owner`, `fuel`, `fuelprice`, `balance`, `label`) VALUES (24, 0, '0', 100000, 3, 0, "Rex\'s Diner Globe Oil");

INSERT IGNORE INTO `fuel_stations` (`location`, `owned`, `owner`, `fuel`, `fuelprice`, `balance`, `label`) VALUES (25, 0, '0', 100000, 3, 0, 'Palmino Freeway Ron');

INSERT IGNORE INTO `fuel_stations` (`location`, `owned`, `owner`, `fuel`, `fuelprice`, `balance`, `label`) VALUES (26, 0, '0', 100000, 3, 0, 'North Rockford LTD');

INSERT IGNORE INTO `fuel_stations` (`location`, `owned`, `owner`, `fuel`, `fuelprice`, `balance`, `label`) VALUES (27, 0, '0', 100000, 3, 0, 'Alta Street Globe Oil');


SET FOREIGN_KEY_CHECKS = 1;
