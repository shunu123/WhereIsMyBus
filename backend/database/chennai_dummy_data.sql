-- Chennai Dummy Data Seeding Script
-- Generated for college_bus database

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+05:30";

-- 1. Insert Dummy Buses
INSERT INTO `buses` (`bus_no`, `label`) VALUES
('TN-01-AX-1010', 'Chennai Express A1'),
('TN-07-BY-2020', 'Adyar Shuttle B2'),
('TN-22-CZ-3030', 'T-Nagar Connect C3');

-- 2. Insert Dummy Routes
INSERT INTO `routes` (`ext_route_id`, `name`) VALUES
('CH-001', 'Marina Beach - Guindy'),
('CH-002', 'T-Nagar - Adyar');

-- 3. Insert Dummy Stops near Chennai Landmarks
INSERT INTO `stops` (`ext_stop_id`, `name`, `lat`, `lng`, `is_active`) VALUES
('ST-CH01', 'Marina Beach Gate 1', 13.0418, 80.2858, 1),
('ST-CH02', 'Mylapore Railway Station', 13.0330, 80.2676, 1),
('ST-CH03', 'T-Nagar Bus Terminus', 13.0418, 80.2337, 1),
('ST-CH04', 'Adyar Depo', 13.0033, 80.2550, 1),
('ST-CH05', 'Guindy Industrial Estate', 13.0067, 80.2206, 1),
('ST-CH06', 'Little Mount', 13.0206, 80.2246, 1);

-- 4. Create dummy trips for today
-- Assuming today's date for testing
SET @today = CURDATE();

INSERT INTO `trips` (`ext_trip_id`, `route_id`, `bus_id`, `service_date`, `start_time`, `end_time`, `status`) VALUES
('TR-CH01', 1, 1, @today, '08:00:00', '09:30:00', 'RUNNING'),
('TR-CH02', 2, 2, @today, '08:15:00', '09:45:00', 'RUNNING');

-- 5. Insert GPS Points for the running buses (Approximate locations)
-- Bus 1 near Marina/Mylapore
INSERT INTO `gps_points` (`trip_id`, `bus_id`, `ext_vehicle_id`, `ext_trip_id`, `ts`, `lat`, `lng`, `speed`, `heading`, `route_name`, `route_id_str`, `direction`) VALUES
(NULL, 1, 'V1010', 'TR-CH01', NOW(), 13.0374, 80.2767, 45.5, 180.0, 'Marina Beach - Guindy', 'CH-001', 'Guindy Bound');

-- Bus 2 near T-Nagar/Adyar
INSERT INTO `gps_points` (`trip_id`, `bus_id`, `ext_vehicle_id`, `ext_trip_id`, `ts`, `lat`, `lng`, `speed`, `heading`, `route_name`, `route_id_str`, `direction`) VALUES
(NULL, 2, 'V2020', 'TR-CH02', NOW(), 13.0225, 80.2443, 30.2, 90.0, 'T-Nagar - Adyar', 'CH-002', 'Adyar Bound');

COMMIT;
