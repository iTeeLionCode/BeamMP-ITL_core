SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";

-- blockings

CREATE TABLE `blockings` (
  `id` int NOT NULL,
  `server_id` int DEFAULT NULL,
  `user_id` int NOT NULL,
  `type` enum('ban','kick','mute') NOT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `cancel_at` datetime NOT NULL,
  `is_canceled` tinyint(1) NOT NULL DEFAULT '0',
  `reason` text NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;

ALTER TABLE `blockings`
  ADD PRIMARY KEY (`id`),
  ADD KEY `blockings_ibfk_1` (`server_id`),
  ADD KEY `user_id` (`user_id`);

ALTER TABLE `blockings`
  MODIFY `id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=1;

-- cmd_permissions

CREATE TABLE `cmd_permissions` (
  `id` int NOT NULL,
  `server_id` int NOT NULL,
  `cmd` varchar(100) NOT NULL,
  `entity` enum('user','group') NOT NULL,
  `entity_id` int NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;

ALTER TABLE `cmd_permissions`
  ADD PRIMARY KEY (`id`),
  ADD KEY `server_id` (`server_id`);

ALTER TABLE `cmd_permissions`
  MODIFY `id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=8;

INSERT INTO `cmd_permissions` (`id`, `server_id`, `cmd`, `entity`, `entity_id`) VALUES
(1, 1, 'ban', 'group', 2),
(2, 1, 'kick', 'group', 2),
(3, 1, 'mute', 'group', 2),
(4, 1, 'whoami', 'group', 1),
(5, 1, 'playerslist', 'group', 1),
(6, 1, 'players', 'group', 1),
(7, 1, 'playters2', 'group', 2);

-- groups

CREATE TABLE `groups` (
  `id` int NOT NULL,
  `name` varchar(250) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;

INSERT INTO `groups` (`id`, `name`) VALUES
(1, 'user'),
(2, 'admin');

ALTER TABLE `groups`
  ADD PRIMARY KEY (`id`);

ALTER TABLE `groups`
  MODIFY `id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

-- servers

CREATE TABLE `servers` (
  `id` int NOT NULL,
  `name` varchar(250) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;

INSERT INTO `servers` (`id`, `name`) VALUES
(1, 'My first server');

ALTER TABLE `servers`
  ADD PRIMARY KEY (`id`);

ALTER TABLE `servers`
  MODIFY `id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

-- users

CREATE TABLE `users` (
  `id` int NOT NULL,
  `player_name` text CHARACTER SET utf8mb3 COLLATE utf8mb3_general_ci NOT NULL,
  `comment` text
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;

ALTER TABLE `users`
  ADD PRIMARY KEY (`id`);

ALTER TABLE `users`
  MODIFY `id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=1;

-- users_groups

CREATE TABLE `users_groups` (
  `id` int NOT NULL,
  `server_id` int NOT NULL,
  `user_id` int NOT NULL,
  `group_id` int NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;

ALTER TABLE `users_groups`
  ADD PRIMARY KEY (`id`),
  ADD KEY `server_id` (`server_id`),
  ADD KEY `group_id` (`group_id`),
  ADD KEY `user_id` (`user_id`);

ALTER TABLE `users_groups`
  MODIFY `id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

-- users_stats

CREATE TABLE `users_stats` (
  `id` int NOT NULL,
  `server_id` int NOT NULL,
  `user_id` int DEFAULT NULL,
  `player_name` varchar(250) CHARACTER SET utf8mb3 COLLATE utf8mb3_general_ci NOT NULL,
  `connect_date` datetime NOT NULL,
  `disconnect_date` datetime DEFAULT NULL,
  `ip` varchar(40) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;

ALTER TABLE `users_stats`
  ADD PRIMARY KEY (`id`),
  ADD KEY `server_id` (`server_id`),
  ADD KEY `user_id` (`user_id`);

ALTER TABLE `users_stats`
  MODIFY `id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=1;

COMMIT;
