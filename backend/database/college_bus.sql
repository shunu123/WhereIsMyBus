-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Host: localhost
-- Generation Time: Mar 13, 2026 at 06:28 AM
-- Server version: 10.4.28-MariaDB
-- PHP Version: 8.2.4

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `college_bus`
--

-- --------------------------------------------------------

--
-- Table structure for table `buses`
--
-- Creation: Feb 21, 2026 at 08:13 AM
-- Last update: Mar 13, 2026 at 05:13 AM
--

CREATE TABLE `buses` (
  `id` bigint(20) UNSIGNED NOT NULL,
  `bus_no` varchar(30) NOT NULL,
  `label` varchar(80) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- RELATIONSHIPS FOR TABLE `buses`:
--

-- --------------------------------------------------------

--
-- Table structure for table `gps_points`
--
-- Creation: Mar 07, 2026 at 07:26 AM
--

CREATE TABLE `gps_points` (
  `id` bigint(20) UNSIGNED NOT NULL,
  `trip_id` int(11) DEFAULT NULL,
  `bus_id` int(11) DEFAULT NULL,
  `ext_vehicle_id` varchar(128) DEFAULT NULL,
  `ext_trip_id` varchar(128) DEFAULT NULL,
  `ts` datetime NOT NULL,
  `lat` decimal(10,7) NOT NULL,
  `lng` decimal(10,7) NOT NULL,
  `speed` float DEFAULT NULL,
  `heading` float DEFAULT NULL,
  `route_name` varchar(64) DEFAULT NULL,
  `route_id_str` varchar(16) DEFAULT NULL,
  `direction` varchar(32) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- RELATIONSHIPS FOR TABLE `gps_points`:
--

-- --------------------------------------------------------

--
-- Table structure for table `otp_codes`
--
-- Creation: Feb 22, 2026 at 07:13 PM
-- Last update: Mar 13, 2026 at 05:19 AM
--

CREATE TABLE `otp_codes` (
  `target` varchar(255) NOT NULL,
  `code` varchar(6) NOT NULL,
  `expires_at` datetime NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- RELATIONSHIPS FOR TABLE `otp_codes`:
--

-- --------------------------------------------------------

--
-- Table structure for table `recent_searches`
--
-- Creation: Mar 07, 2026 at 07:15 AM
--

CREATE TABLE `recent_searches` (
  `id` bigint(20) UNSIGNED NOT NULL,
  `from_stop_id` bigint(20) UNSIGNED NOT NULL,
  `to_stop_id` bigint(20) UNSIGNED NOT NULL,
  `ts` datetime DEFAULT current_timestamp(),
  `role` varchar(20) DEFAULT 'student',
  `user_id` int(11) DEFAULT NULL,
  `from_name` varchar(255) DEFAULT NULL,
  `to_name` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- RELATIONSHIPS FOR TABLE `recent_searches`:
--   `from_stop_id`
--       `stops` -> `id`
--   `to_stop_id`
--       `stops` -> `id`
--

-- --------------------------------------------------------

--
-- Table structure for table `routes`
--
-- Creation: Feb 28, 2026 at 05:49 AM
--

CREATE TABLE `routes` (
  `id` bigint(20) UNSIGNED NOT NULL,
  `ext_route_id` varchar(64) DEFAULT NULL,
  `name` varchar(120) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- RELATIONSHIPS FOR TABLE `routes`:
--

-- --------------------------------------------------------

--
-- Table structure for table `route_stops`
--
-- Creation: Mar 01, 2026 at 05:46 PM
--

CREATE TABLE `route_stops` (
  `route_id` bigint(20) UNSIGNED NOT NULL,
  `stop_id` bigint(20) UNSIGNED NOT NULL,
  `stop_order` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- RELATIONSHIPS FOR TABLE `route_stops`:
--   `route_id`
--       `routes` -> `id`
--   `stop_id`
--       `stops` -> `id`
--

-- --------------------------------------------------------

--
-- Table structure for table `stops`
--
-- Creation: Feb 28, 2026 at 05:49 AM
--

CREATE TABLE `stops` (
  `id` bigint(20) UNSIGNED NOT NULL,
  `ext_stop_id` varchar(64) DEFAULT NULL,
  `name` varchar(120) NOT NULL,
  `lat` decimal(10,7) NOT NULL,
  `lng` decimal(10,7) NOT NULL,
  `is_active` tinyint(1) DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- RELATIONSHIPS FOR TABLE `stops`:
--

-- --------------------------------------------------------

--
-- Table structure for table `trips`
--
-- Creation: Mar 02, 2026 at 04:37 AM
-- Last update: Mar 13, 2026 at 05:13 AM
--

CREATE TABLE `trips` (
  `id` bigint(20) UNSIGNED NOT NULL,
  `ext_trip_id` varchar(128) DEFAULT NULL,
  `route_id` bigint(20) UNSIGNED NOT NULL,
  `bus_id` int(11) DEFAULT NULL,
  `service_date` date NOT NULL,
  `start_time` time DEFAULT NULL,
  `end_time` time DEFAULT NULL,
  `status` enum('SCHEDULED','RUNNING','COMPLETED','CANCELLED') DEFAULT 'SCHEDULED'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- RELATIONSHIPS FOR TABLE `trips`:
--   `route_id`
--       `routes` -> `id`
--

-- --------------------------------------------------------

--
-- Table structure for table `trip_stop_eta`
--
-- Creation: Mar 01, 2026 at 05:53 PM
--

CREATE TABLE `trip_stop_eta` (
  `ext_trip_id` varchar(128) NOT NULL,
  `ext_stop_id` varchar(64) NOT NULL,
  `eta_ts` datetime DEFAULT NULL,
  `delay_sec` int(11) DEFAULT NULL,
  `updated_at` datetime DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- RELATIONSHIPS FOR TABLE `trip_stop_eta`:
--

-- --------------------------------------------------------

--
-- Table structure for table `trip_stop_times`
--
-- Creation: Mar 02, 2026 at 05:26 AM
-- Last update: Mar 13, 2026 at 05:15 AM
--

CREATE TABLE `trip_stop_times` (
  `trip_id` bigint(20) UNSIGNED NOT NULL,
  `stop_id` bigint(20) UNSIGNED NOT NULL,
  `stop_order` int(11) NOT NULL,
  `sched_arrival` time DEFAULT NULL,
  `sched_departure` time DEFAULT NULL,
  `actual_arrival` datetime DEFAULT NULL,
  `actual_departure` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- RELATIONSHIPS FOR TABLE `trip_stop_times`:
--   `stop_id`
--       `stops` -> `id`
--   `trip_id`
--       `trips` -> `id`
--

-- --------------------------------------------------------

--
-- Table structure for table `users`
--
-- Creation: Feb 22, 2026 at 08:59 PM
-- Last update: Mar 13, 2026 at 05:20 AM
--

CREATE TABLE `users` (
  `id` int(11) NOT NULL,
  `reg_no` varchar(20) NOT NULL,
  `password` varchar(255) NOT NULL,
  `first_name` varchar(100) NOT NULL,
  `last_name` varchar(100) DEFAULT NULL,
  `year` int(11) DEFAULT 1,
  `mobile_no` varchar(15) DEFAULT NULL,
  `email` varchar(255) DEFAULT NULL,
  `college_name` varchar(255) DEFAULT NULL,
  `department` varchar(255) DEFAULT NULL,
  `specialization` varchar(255) DEFAULT NULL,
  `degree` varchar(255) DEFAULT NULL,
  `location` varchar(255) DEFAULT NULL,
  `bus_stop` varchar(255) DEFAULT NULL,
  `role` varchar(20) DEFAULT 'student'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- RELATIONSHIPS FOR TABLE `users`:
--

--
-- Indexes for dumped tables
--

--
-- Indexes for table `buses`
--
ALTER TABLE `buses`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `uq_bus_no` (`bus_no`);

--
-- Indexes for table `gps_points`
--
ALTER TABLE `gps_points`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `uniq_ext_vehicle` (`ext_vehicle_id`),
  ADD KEY `idx_trip_ts` (`trip_id`,`ts`),
  ADD KEY `idx_bus_ts` (`bus_id`,`ts`),
  ADD KEY `idx_gps_vehicle_ts` (`ext_vehicle_id`,`ts`),
  ADD KEY `idx_gps_trip_ts` (`trip_id`,`ts`),
  ADD KEY `idx_gps_ext_v` (`ext_vehicle_id`,`ts`),
  ADD KEY `idx_gps_ext_t` (`ext_trip_id`,`ts`);

--
-- Indexes for table `otp_codes`
--
ALTER TABLE `otp_codes`
  ADD PRIMARY KEY (`target`);

--
-- Indexes for table `recent_searches`
--
ALTER TABLE `recent_searches`
  ADD PRIMARY KEY (`id`),
  ADD KEY `from_stop_id` (`from_stop_id`),
  ADD KEY `to_stop_id` (`to_stop_id`);

--
-- Indexes for table `routes`
--
ALTER TABLE `routes`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `ext_route_id` (`ext_route_id`);

--
-- Indexes for table `route_stops`
--
ALTER TABLE `route_stops`
  ADD PRIMARY KEY (`route_id`,`stop_order`),
  ADD KEY `fk_rs_stop` (`stop_id`);

--
-- Indexes for table `stops`
--
ALTER TABLE `stops`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `ext_stop_id` (`ext_stop_id`);

--
-- Indexes for table `trips`
--
ALTER TABLE `trips`
  ADD PRIMARY KEY (`id`),
  ADD KEY `fk_trip_route` (`route_id`),
  ADD KEY `fk_trip_bus` (`bus_id`),
  ADD KEY `idx_trips_ext_id` (`ext_trip_id`),
  ADD KEY `idx_trips_ext_trip_id` (`ext_trip_id`);

--
-- Indexes for table `trip_stop_eta`
--
ALTER TABLE `trip_stop_eta`
  ADD PRIMARY KEY (`ext_trip_id`,`ext_stop_id`);

--
-- Indexes for table `trip_stop_times`
--
ALTER TABLE `trip_stop_times`
  ADD PRIMARY KEY (`trip_id`,`stop_order`),
  ADD KEY `fk_tst_stop` (`stop_id`);

--
-- Indexes for table `users`
--
ALTER TABLE `users`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `reg_no` (`reg_no`),
  ADD UNIQUE KEY `email` (`email`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `buses`
--
ALTER TABLE `buses`
  MODIFY `id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `gps_points`
--
ALTER TABLE `gps_points`
  MODIFY `id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `recent_searches`
--
ALTER TABLE `recent_searches`
  MODIFY `id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `routes`
--
ALTER TABLE `routes`
  MODIFY `id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `stops`
--
ALTER TABLE `stops`
  MODIFY `id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `trips`
--
ALTER TABLE `trips`
  MODIFY `id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `users`
--
ALTER TABLE `users`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- Constraints for dumped tables
--

--
-- Constraints for table `recent_searches`
--
ALTER TABLE `recent_searches`
  ADD CONSTRAINT `recent_searches_ibfk_1` FOREIGN KEY (`from_stop_id`) REFERENCES `stops` (`id`),
  ADD CONSTRAINT `recent_searches_ibfk_2` FOREIGN KEY (`to_stop_id`) REFERENCES `stops` (`id`);

--
-- Constraints for table `route_stops`
--
ALTER TABLE `route_stops`
  ADD CONSTRAINT `fk_rs_route` FOREIGN KEY (`route_id`) REFERENCES `routes` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `fk_rs_stop` FOREIGN KEY (`stop_id`) REFERENCES `stops` (`id`);

--
-- Constraints for table `trips`
--
ALTER TABLE `trips`
  ADD CONSTRAINT `fk_trip_route` FOREIGN KEY (`route_id`) REFERENCES `routes` (`id`);

--
-- Constraints for table `trip_stop_times`
--
ALTER TABLE `trip_stop_times`
  ADD CONSTRAINT `fk_tst_stop` FOREIGN KEY (`stop_id`) REFERENCES `stops` (`id`),
  ADD CONSTRAINT `fk_tst_trip` FOREIGN KEY (`trip_id`) REFERENCES `trips` (`id`) ON DELETE CASCADE;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
