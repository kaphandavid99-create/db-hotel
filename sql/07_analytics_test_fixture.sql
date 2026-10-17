-- Run in the same MySQL session used for sql/06_analytics.sql.
-- The temporary tables shadow the real tables, so no persistent data is changed.
-- First create the schema with sql/01_schema.sql, then run this file, set the
-- session variables below, and execute sql/06_analytics.sql in this same session.
USE hotel_management;

DROP TEMPORARY TABLE IF EXISTS reviews;
DROP TEMPORARY TABLE IF EXISTS payments;
DROP TEMPORARY TABLE IF EXISTS invoice_lines;
DROP TEMPORARY TABLE IF EXISTS invoices;
DROP TEMPORARY TABLE IF EXISTS service_bookings;
DROP TEMPORARY TABLE IF EXISTS services;
DROP TEMPORARY TABLE IF EXISTS reservation_rooms;
DROP TEMPORARY TABLE IF EXISTS reservations;
DROP TEMPORARY TABLE IF EXISTS clients;
DROP TEMPORARY TABLE IF EXISTS rooms;
DROP TEMPORARY TABLE IF EXISTS room_types;

CREATE TEMPORARY TABLE room_types LIKE hotel_management.room_types;
CREATE TEMPORARY TABLE rooms LIKE hotel_management.rooms;
CREATE TEMPORARY TABLE clients LIKE hotel_management.clients;
CREATE TEMPORARY TABLE reservations LIKE hotel_management.reservations;
CREATE TEMPORARY TABLE reservation_rooms LIKE hotel_management.reservation_rooms;
CREATE TEMPORARY TABLE services LIKE hotel_management.services;
CREATE TEMPORARY TABLE service_bookings LIKE hotel_management.service_bookings;
CREATE TEMPORARY TABLE invoices LIKE hotel_management.invoices;
CREATE TEMPORARY TABLE invoice_lines LIKE hotel_management.invoice_lines;
CREATE TEMPORARY TABLE payments LIKE hotel_management.payments;
CREATE TEMPORARY TABLE reviews LIKE hotel_management.reviews;

INSERT INTO room_types (room_type_id, type_name) VALUES
    (1, 'Standard'),
    (2, 'Deluxe'),
    (3, 'Suite'),
    (4, 'No Rooms');

INSERT INTO rooms
    (room_id, room_number, floor_number, room_type_id, max_capacity, base_price_per_night, operational_status)
VALUES
    (101, '101', 1, 1, 2, 45000.00, 'available'),
    (102, '102', 1, 1, 2, 45000.00, 'out_of_service'),
    (103, '103', 1, 1, 2, 45000.00, 'available'),
    (201, '201', 2, 2, 2, 65000.00, 'occupied'),
    (301, '301', 3, 3, 4, 125000.00, 'available');

INSERT INTO clients (client_id, last_name, first_name, phone, email) VALUES
    (1, 'Example', 'Ada', '+237600000001', 'ada@example.test'),
    (2, 'Example', 'Ben', '+237600000002', 'ben@example.test'),
    (3, 'Example', 'Cami', '+237600000003', 'cami@example.test'),
    (4, 'Example', 'Dee', '+237600000004', 'dee@example.test');

-- Res 1 reserves two room types, deliberately testing room-night multiplication.
-- Res 2 is pending and overlaps room 103; it must neither block nor count as sold.
-- Res 3 is completed and counts as sold inventory.
-- Res 4 is cancelled and must not count as occupied, collectible, or spending.
-- Res 5 is a July confirmed stay.
-- Res 6 deliberately duplicates res 1's room/date interval to test occupancy de-duplication.
INSERT INTO reservations
    (reservation_id, client_id, check_in_date, check_out_date, guest_count, reservation_status, created_at, cancelled_at)
VALUES
    (1, 1, '2026-06-01', '2026-06-03', 2, 'confirmed', '2026-05-01 09:00:00', NULL),
    (2, 2, '2026-06-02', '2026-06-04', 1, 'pending', '2026-05-02 09:00:00', NULL),
    (3, 2, '2026-06-03', '2026-06-05', 2, 'completed', '2026-05-03 09:00:00', NULL),
    (4, 3, '2026-06-04', '2026-06-06', 2, 'cancelled', '2026-05-04 09:00:00', '2026-05-10 10:00:00'),
    (5, 3, '2026-07-10', '2026-07-12', 2, 'confirmed', '2026-06-01 09:00:00', NULL),
    (6, 4, '2026-06-01', '2026-06-03', 2, 'confirmed', '2026-05-05 09:00:00', NULL);

INSERT INTO reservation_rooms (reservation_id, room_id, booked_price_per_night) VALUES
    (1, 101, 45000.00),
    (1, 201, 65000.00),
    (2, 103, 45000.00),
    (3, 201, 65000.00),
    (4, 301, 125000.00),
    (5, 301, 125000.00),
    (6, 101, 45000.00);

INSERT INTO services (service_id, service_name, description, price, slot_capacity) VALUES
    (1, 'Test breakfast', 'Fixture service item', 100.00, 10);
INSERT INTO service_bookings
    (service_booking_id, reservation_id, service_id, slot_start, slot_end, quantity, booked_unit_price)
VALUES
    (1, 1, 1, '2026-06-02 08:00:00', '2026-06-02 09:00:00', 1, 100.00);

INSERT INTO invoices (invoice_id, reservation_id, issued_at, status) VALUES
    (501, 1, '2026-06-03 12:00:00', 'paid'),
    (502, 3, '2026-06-05 12:00:00', 'partially_paid'),
    (503, 4, '2026-06-06 12:00:00', 'paid'),
    (504, 5, '2026-07-12 12:00:00', 'partially_paid');

INSERT INTO invoice_lines
    (invoice_line_id, invoice_id, line_type, description, quantity, unit_price, tax_rate)
VALUES
    (1, 501, 'accommodation', 'Two room nights', 2.00, 100.00, 0.00),
    (2, 501, 'service', 'Breakfast', 1.00, 100.00, 10.00),
    (3, 501, 'miscellaneous', 'Parking', 1.00, 20.00, 0.00),
    (4, 502, 'accommodation', 'Completed stay', 2.00, 150.00, 0.00),
    (5, 503, 'accommodation', 'Cancelled stay', 1.00, 200.00, 0.00),
    (6, 504, 'accommodation', 'July stay', 2.00, 125.00, 0.00);

-- Res 1 has an overpayment: analytics must cap paid revenue at its 330 invoice total.
-- Res 3 and 5 are partially paid; the outstanding report should show balances 150, 50.
-- The cancelled reservation's payment must be excluded from revenue/spending.
INSERT INTO payments (payment_id, invoice_id, payment_date, amount, method) VALUES
    (1, 501, '2026-06-05 10:00:00', 100.00, 'card'),
    (2, 501, '2026-06-06 10:00:00', 300.00, 'cash'),
    (3, 502, '2026-07-01 10:00:00', 150.00, 'bank_transfer'),
    (4, 503, '2026-06-07 10:00:00', 200.00, 'card'),
    (5, 504, '2026-07-13 10:00:00', 200.00, 'mobile_money');

INSERT INTO reviews (review_id, reservation_id, rating, comment, review_date) VALUES
    (1, 1, 5, 'Fixture review on two room types', '2026-06-04'),
    (2, 3, 3, 'Fixture second review for Deluxe', '2026-06-06');

SET @room_type_name = 'Standard';
SET @check_in_date = '2026-06-02';
SET @check_out_date = '2026-06-04';
SET @report_start = '2026-06-01';
SET @report_end = '2026-08-01';

-- Expected checks when sql/06_analytics.sql is run after this fixture:
-- 1. Room search returns only room 103 (room 101 conflicts; 102 is out of service;
--    pending reservation 2 does not block).
-- 2. Occupancy: June = 6/150 = 4.00%; July = 2/155 = 1.29%.
-- 3. June paid revenue totals 330.00, split approximately 200.00 accommodation,
--    110.00 services, 20.00 miscellaneous. July total is 350.00
--    (150.00 accommodation for res 3 + 200.00 for res 5).
-- 4. Unpaid invoices: 502 balance 150.00 and 504 balance 50.00, oldest first;
--    paid invoice 501 and cancelled reservation invoice 503 are absent.
-- 5. Standard average 5.00/count 1; Deluxe average 4.00/count 2;
--    Suite and No Rooms both appear with NULL average/count 0.
-- 6. Top client spending: Ada 330.00/1 stay; Cami 200.00/1 stay;
--    Ben 150.00/1 stay. Pending and cancelled stays are not counted.

-- Zero-available-night edge case: after checking all six results above, run
-- DELETE FROM rooms; and execute query 2 again. It must return 0 available nights
-- and a 0.00% rate without division-by-zero. This only deletes this session's
-- temporary fixture rows, not persistent room records.