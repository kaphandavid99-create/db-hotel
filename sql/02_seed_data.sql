USE hotel_management;

-- Development/demo seed data only. No persistent rows are deleted or reset.
-- Seed clients use the reserved .invalid domain; room/service labels use a
-- "Seed" namespace. Reruns find these rows by their natural keys/signatures.
-- The anchor date is recovered from the first seed reservation after the initial
-- run, so rerunning on another day does not create a second date-shifted dataset.
SET @seed_anchor_date = COALESCE(
    (
        SELECT DATE_ADD(reservation.check_in_date, INTERVAL 100 DAY)
        FROM reservations AS reservation
        INNER JOIN clients AS client
            ON client.client_id = reservation.client_id
        WHERE client.email = 'seed.client01@dbhotel.invalid'
          AND reservation.guest_count = 2
          AND reservation.check_out_date = DATE_ADD(reservation.check_in_date, INTERVAL 3 DAY)
        ORDER BY reservation.reservation_id
        LIMIT 1
    ),
    CURDATE()
);

DROP TEMPORARY TABLE IF EXISTS _seed_review_rows;
DROP TEMPORARY TABLE IF EXISTS _seed_payment_cases;
DROP TEMPORARY TABLE IF EXISTS _seed_invoice_map;
DROP TEMPORARY TABLE IF EXISTS _seed_reservation_map;
DROP TEMPORARY TABLE IF EXISTS _seed_activatable_reservations;
DROP TEMPORARY TABLE IF EXISTS _seed_preexisting_reservations;
DROP TEMPORARY TABLE IF EXISTS _seed_service_bookings;
DROP TEMPORARY TABLE IF EXISTS _seed_service_hours;
DROP TEMPORARY TABLE IF EXISTS _seed_services;
DROP TEMPORARY TABLE IF EXISTS _seed_reservation_rooms;
DROP TEMPORARY TABLE IF EXISTS _seed_reservations;
DROP TEMPORARY TABLE IF EXISTS _seed_rooms;
DROP TEMPORARY TABLE IF EXISTS _seed_room_types;
DROP TEMPORARY TABLE IF EXISTS _seed_clients;

CREATE TEMPORARY TABLE _seed_clients (
    seed_no TINYINT UNSIGNED NOT NULL PRIMARY KEY,
    first_name VARCHAR(80) NOT NULL,
    last_name VARCHAR(80) NOT NULL,
    phone VARCHAR(25) NOT NULL,
    email VARCHAR(254) NOT NULL
);

INSERT INTO _seed_clients (seed_no, first_name, last_name, phone, email) VALUES
    (1, 'Amelia', 'Nkomo', '+237690001001', 'seed.client01@dbhotel.invalid'),
    (2, 'Samuel', 'Tchoumi', '+237690001002', 'seed.client02@dbhotel.invalid'),
    (3, 'Nadia', 'Mabiala', '+237690001003', 'seed.client03@dbhotel.invalid'),
    (4, 'Armand', 'Fotso', '+237690001004', 'seed.client04@dbhotel.invalid'),
    (5, 'Grace', 'Ngono', '+237690001005', 'seed.client05@dbhotel.invalid'),
    (6, 'Patrick', 'Moukoko', '+237690001006', 'seed.client06@dbhotel.invalid'),
    (7, 'Chantal', 'Biloa', '+237690001007', 'seed.client07@dbhotel.invalid'),
    (8, 'Emmanuel', 'Talla', '+237690001008', 'seed.client08@dbhotel.invalid'),
    (9, 'Esther', 'Fouda', '+237690001009', 'seed.client09@dbhotel.invalid'),
    (10, 'David', 'Ewane', '+237690001010', 'seed.client10@dbhotel.invalid'),
    (11, 'Carine', 'Atangana', '+237690001011', 'seed.client11@dbhotel.invalid'),
    (12, 'Michel', 'Manga', '+237690001012', 'seed.client12@dbhotel.invalid');

CREATE TEMPORARY TABLE _seed_room_types (
    type_name VARCHAR(40) NOT NULL PRIMARY KEY
);

INSERT INTO _seed_room_types (type_name) VALUES
    ('Garden Queen'),
    ('Courtyard Twin'),
    ('Deluxe King'),
    ('Harbor Suite');

CREATE TEMPORARY TABLE _seed_rooms (
    room_number VARCHAR(10) NOT NULL PRIMARY KEY,
    floor_number SMALLINT NOT NULL,
    type_name VARCHAR(40) NOT NULL,
    max_capacity TINYINT UNSIGNED NOT NULL,
    nightly_price DECIMAL(10,2) NOT NULL
);

INSERT INTO _seed_rooms (room_number, floor_number, type_name, max_capacity, nightly_price) VALUES
    ('SD-101', 1, 'Garden Queen', 2, 45000.00),
    ('SD-102', 1, 'Garden Queen', 2, 45000.00),
    ('SD-103', 1, 'Garden Queen', 2, 45000.00),
    ('SD-104', 1, 'Garden Queen', 2, 45000.00),
    ('SD-201', 2, 'Courtyard Twin', 2, 50000.00),
    ('SD-202', 2, 'Courtyard Twin', 2, 50000.00),
    ('SD-203', 2, 'Courtyard Twin', 2, 50000.00),
    ('SD-301', 3, 'Deluxe King', 2, 65000.00),
    ('SD-302', 3, 'Deluxe King', 2, 65000.00),
    ('SD-303', 3, 'Deluxe King', 2, 65000.00),
    ('SD-501', 5, 'Harbor Suite', 4, 125000.00),
    ('SD-502', 5, 'Harbor Suite', 4, 125000.00);

CREATE TEMPORARY TABLE _seed_services (
    service_name VARCHAR(100) NOT NULL PRIMARY KEY,
    description VARCHAR(500) NOT NULL,
    price DECIMAL(10,2) NOT NULL,
    slot_capacity SMALLINT UNSIGNED NOT NULL
);

INSERT INTO _seed_services (service_name, description, price, slot_capacity) VALUES
    ('Seed Breakfast Delivery', 'Cameroonian and continental breakfast delivered to the guest room.', 12000.00, 24),
    ('Seed Spa Session', 'Relaxing massage and wellness treatment by appointment.', 75000.00, 8),
    ('Seed Restaurant Dining', 'Table reservation for local and international cuisine.', 45000.00, 30),
    ('Seed Airport Transfer', 'Private transfer between the hotel and Douala International Airport.', 35000.00, 12);

CREATE TEMPORARY TABLE _seed_service_hours (
    service_name VARCHAR(100) NOT NULL,
    day_of_week TINYINT UNSIGNED NOT NULL,
    opens_at TIME NOT NULL,
    closes_at TIME NOT NULL,
    PRIMARY KEY (service_name, day_of_week)
);

-- Monday = 1; the spa is closed on Sunday. Weekday/weekend hours differ.
INSERT INTO _seed_service_hours (service_name, day_of_week, opens_at, closes_at) VALUES
    ('Seed Breakfast Delivery', 1, '06:00:00', '10:00:00'),
    ('Seed Breakfast Delivery', 2, '06:00:00', '10:00:00'),
    ('Seed Breakfast Delivery', 3, '06:00:00', '10:00:00'),
    ('Seed Breakfast Delivery', 4, '06:00:00', '10:00:00'),
    ('Seed Breakfast Delivery', 5, '06:00:00', '10:00:00'),
    ('Seed Breakfast Delivery', 6, '07:00:00', '11:00:00'),
    ('Seed Breakfast Delivery', 7, '07:00:00', '11:00:00'),
    ('Seed Spa Session', 1, '09:00:00', '18:00:00'),
    ('Seed Spa Session', 2, '09:00:00', '18:00:00'),
    ('Seed Spa Session', 3, '09:00:00', '18:00:00'),
    ('Seed Spa Session', 4, '09:00:00', '18:00:00'),
    ('Seed Spa Session', 5, '09:00:00', '19:00:00'),
    ('Seed Spa Session', 6, '09:00:00', '19:00:00'),
    ('Seed Restaurant Dining', 1, '17:00:00', '22:00:00'),
    ('Seed Restaurant Dining', 2, '17:00:00', '22:00:00'),
    ('Seed Restaurant Dining', 3, '17:00:00', '22:00:00'),
    ('Seed Restaurant Dining', 4, '17:00:00', '22:00:00'),
    ('Seed Restaurant Dining', 5, '17:00:00', '23:00:00'),
    ('Seed Restaurant Dining', 6, '17:00:00', '23:00:00'),
    ('Seed Restaurant Dining', 7, '16:00:00', '21:00:00'),
    ('Seed Airport Transfer', 1, '05:00:00', '23:00:00'),
    ('Seed Airport Transfer', 2, '05:00:00', '23:00:00'),
    ('Seed Airport Transfer', 3, '05:00:00', '23:00:00'),
    ('Seed Airport Transfer', 4, '05:00:00', '23:00:00'),
    ('Seed Airport Transfer', 5, '05:00:00', '23:00:00'),
    ('Seed Airport Transfer', 6, '06:00:00', '22:00:00'),
    ('Seed Airport Transfer', 7, '06:00:00', '22:00:00');

CREATE TEMPORARY TABLE _seed_reservations (
    seed_no TINYINT UNSIGNED NOT NULL PRIMARY KEY,
    client_email VARCHAR(254) NOT NULL,
    check_in_date DATE NOT NULL,
    check_out_date DATE NOT NULL,
    guest_count SMALLINT UNSIGNED NOT NULL,
    reservation_status VARCHAR(12) NOT NULL
);

INSERT INTO _seed_reservations
    (seed_no, client_email, check_in_date, check_out_date, guest_count, reservation_status)
VALUES
    (1, 'seed.client01@dbhotel.invalid', DATE_SUB(@seed_anchor_date, INTERVAL 100 DAY), DATE_SUB(@seed_anchor_date, INTERVAL 97 DAY), 2, 'completed'),
    (2, 'seed.client02@dbhotel.invalid', DATE_SUB(@seed_anchor_date, INTERVAL 90 DAY), DATE_SUB(@seed_anchor_date, INTERVAL 88 DAY), 1, 'completed'),
    (3, 'seed.client03@dbhotel.invalid', DATE_SUB(@seed_anchor_date, INTERVAL 80 DAY), DATE_SUB(@seed_anchor_date, INTERVAL 76 DAY), 2, 'completed'),
    (4, 'seed.client04@dbhotel.invalid', DATE_SUB(@seed_anchor_date, INTERVAL 70 DAY), DATE_SUB(@seed_anchor_date, INTERVAL 68 DAY), 2, 'completed'),
    (5, 'seed.client05@dbhotel.invalid', DATE_SUB(@seed_anchor_date, INTERVAL 60 DAY), DATE_SUB(@seed_anchor_date, INTERVAL 57 DAY), 2, 'completed'),
    (6, 'seed.client06@dbhotel.invalid', DATE_SUB(@seed_anchor_date, INTERVAL 50 DAY), DATE_SUB(@seed_anchor_date, INTERVAL 49 DAY), 1, 'completed'),
    (7, 'seed.client07@dbhotel.invalid', DATE_SUB(@seed_anchor_date, INTERVAL 40 DAY), DATE_SUB(@seed_anchor_date, INTERVAL 38 DAY), 2, 'completed'),
    (8, 'seed.client08@dbhotel.invalid', DATE_SUB(@seed_anchor_date, INTERVAL 30 DAY), DATE_SUB(@seed_anchor_date, INTERVAL 27 DAY), 2, 'completed'),
    (9, 'seed.client09@dbhotel.invalid', DATE_SUB(@seed_anchor_date, INTERVAL 20 DAY), DATE_SUB(@seed_anchor_date, INTERVAL 18 DAY), 2, 'completed'),
    (10, 'seed.client10@dbhotel.invalid', DATE_SUB(@seed_anchor_date, INTERVAL 10 DAY), DATE_SUB(@seed_anchor_date, INTERVAL 8 DAY), 2, 'completed'),
    (11, 'seed.client01@dbhotel.invalid', DATE_ADD(@seed_anchor_date, INTERVAL 2 DAY), DATE_ADD(@seed_anchor_date, INTERVAL 5 DAY), 2, 'confirmed'),
    (12, 'seed.client02@dbhotel.invalid', DATE_ADD(@seed_anchor_date, INTERVAL 6 DAY), DATE_ADD(@seed_anchor_date, INTERVAL 8 DAY), 1, 'confirmed'),
    (13, 'seed.client03@dbhotel.invalid', DATE_ADD(@seed_anchor_date, INTERVAL 10 DAY), DATE_ADD(@seed_anchor_date, INTERVAL 14 DAY), 3, 'confirmed'),
    (14, 'seed.client04@dbhotel.invalid', DATE_ADD(@seed_anchor_date, INTERVAL 15 DAY), DATE_ADD(@seed_anchor_date, INTERVAL 17 DAY), 2, 'confirmed'),
    (15, 'seed.client05@dbhotel.invalid', DATE_ADD(@seed_anchor_date, INTERVAL 20 DAY), DATE_ADD(@seed_anchor_date, INTERVAL 23 DAY), 2, 'confirmed'),
    (16, 'seed.client06@dbhotel.invalid', DATE_ADD(@seed_anchor_date, INTERVAL 25 DAY), DATE_ADD(@seed_anchor_date, INTERVAL 27 DAY), 1, 'confirmed'),
    (17, 'seed.client07@dbhotel.invalid', DATE_ADD(@seed_anchor_date, INTERVAL 2 DAY), DATE_ADD(@seed_anchor_date, INTERVAL 4 DAY), 2, 'pending'),
    (18, 'seed.client08@dbhotel.invalid', DATE_ADD(@seed_anchor_date, INTERVAL 8 DAY), DATE_ADD(@seed_anchor_date, INTERVAL 9 DAY), 1, 'pending'),
    (19, 'seed.client09@dbhotel.invalid', DATE_SUB(@seed_anchor_date, INTERVAL 5 DAY), DATE_SUB(@seed_anchor_date, INTERVAL 3 DAY), 2, 'cancelled'),
    (20, 'seed.client10@dbhotel.invalid', DATE_ADD(@seed_anchor_date, INTERVAL 30 DAY), DATE_ADD(@seed_anchor_date, INTERVAL 34 DAY), 4, 'confirmed');

CREATE TEMPORARY TABLE _seed_reservation_rooms (
    seed_no TINYINT UNSIGNED NOT NULL,
    room_number VARCHAR(10) NOT NULL,
    PRIMARY KEY (seed_no, room_number)
);

INSERT INTO _seed_reservation_rooms (seed_no, room_number) VALUES
    (1, 'SD-101'), (2, 'SD-201'), (3, 'SD-301'), (4, 'SD-102'),
    (5, 'SD-202'), (6, 'SD-302'), (7, 'SD-103'), (8, 'SD-203'),
    (9, 'SD-303'), (10, 'SD-104'), (11, 'SD-101'), (12, 'SD-101'),
    (13, 'SD-102'), (14, 'SD-102'), (15, 'SD-103'), (16, 'SD-103'),
    (17, 'SD-201'), (18, 'SD-202'), (19, 'SD-303'), (20, 'SD-501'),
    (20, 'SD-502');

CREATE TEMPORARY TABLE _seed_service_bookings (
    seed_no TINYINT UNSIGNED NOT NULL,
    service_name VARCHAR(100) NOT NULL,
    day_after_check_in TINYINT UNSIGNED NOT NULL,
    starts_at TIME NOT NULL,
    ends_at TIME NOT NULL,
    quantity SMALLINT UNSIGNED NOT NULL,
    PRIMARY KEY (seed_no, service_name)
);

INSERT INTO _seed_service_bookings
    (seed_no, service_name, day_after_check_in, starts_at, ends_at, quantity)
VALUES
    (1, 'Seed Breakfast Delivery', 1, '08:00:00', '09:00:00', 2),
    (2, 'Seed Restaurant Dining', 0, '19:00:00', '21:00:00', 1),
    (3, 'Seed Restaurant Dining', 2, '19:00:00', '21:00:00', 3),
    (4, 'Seed Airport Transfer', 1, '10:00:00', '11:00:00', 1),
    (5, 'Seed Breakfast Delivery', 1, '07:30:00', '08:30:00', 2),
    (6, 'Seed Restaurant Dining', 0, '18:00:00', '20:00:00', 1);

CREATE TEMPORARY TABLE _seed_payment_cases (
    seed_no TINYINT UNSIGNED NOT NULL PRIMARY KEY,
    payment_case VARCHAR(12) NOT NULL
);

INSERT INTO _seed_payment_cases (seed_no, payment_case) VALUES
    (1, 'paid'),
    (2, 'partial'),
    (3, 'due'),
    (4, 'paid'),
    (5, 'paid'),
    (6, 'paid'),
    (7, 'paid'),
    (8, 'paid'),
    (9, 'paid'),
    (10, 'paid');

CREATE TEMPORARY TABLE _seed_review_rows (
    seed_no TINYINT UNSIGNED NOT NULL PRIMARY KEY,
    rating TINYINT UNSIGNED NOT NULL,
    review_comment VARCHAR(1000) NOT NULL
);

INSERT INTO _seed_review_rows (seed_no, rating, review_comment) VALUES
    (1, 5, 'Excellent service, comfortable room, and a lovely breakfast.'),
    (2, 4, 'Very welcoming staff and a convenient location.'),
    (3, 3, 'Good stay overall; restaurant service was slow.'),
    (4, 2, 'The room was clean but maintenance response could improve.'),
    (5, 1, 'Several issues during the stay; needs substantial improvement.'),
    (6, 4, 'Comfortable overnight stay and helpful reception.'),
    (7, 5, 'Excellent experience from check-in to departure.'),
    (8, 3, 'Pleasant room with average service.');

START TRANSACTION;

-- Insert missing catalog rows only; never overwrite an existing property's data.
INSERT INTO room_types (type_name)
SELECT seed.type_name
FROM _seed_room_types AS seed
WHERE NOT EXISTS (
    SELECT 1 FROM room_types AS existing_type WHERE existing_type.type_name = seed.type_name
);

INSERT INTO rooms
    (room_number, floor_number, room_type_id, max_capacity, base_price_per_night, operational_status)
SELECT
    seed.room_number,
    seed.floor_number,
    room_type.room_type_id,
    seed.max_capacity,
    seed.nightly_price,
    'available'
FROM _seed_rooms AS seed
INNER JOIN room_types AS room_type
    ON room_type.type_name = seed.type_name
WHERE NOT EXISTS (
    SELECT 1 FROM rooms AS existing_room WHERE existing_room.room_number = seed.room_number
);

INSERT INTO clients (last_name, first_name, phone, email)
SELECT seed.last_name, seed.first_name, seed.phone, seed.email
FROM _seed_clients AS seed
WHERE NOT EXISTS (
    SELECT 1
    FROM clients AS existing_client
    WHERE existing_client.email = seed.email
       OR existing_client.phone = seed.phone
);

INSERT INTO services (service_name, description, price, slot_capacity)
SELECT seed.service_name, seed.description, seed.price, seed.slot_capacity
FROM _seed_services AS seed
WHERE NOT EXISTS (
    SELECT 1 FROM services AS existing_service WHERE existing_service.service_name = seed.service_name
);

INSERT INTO service_opening_hours (service_id, day_of_week, opens_at, closes_at)
SELECT service.service_id, seed.day_of_week, seed.opens_at, seed.closes_at
FROM _seed_service_hours AS seed
INNER JOIN services AS service
    ON service.service_name = seed.service_name
WHERE NOT EXISTS (
    SELECT 1
    FROM service_opening_hours AS existing_hours
    WHERE existing_hours.service_id = service.service_id
      AND existing_hours.day_of_week = seed.day_of_week
);

-- Reservation identity uses the seeded client's unique email plus dates/guest
-- count. Status is intentionally not part of the key so a later status change
-- does not make a rerun create a duplicate. No AUTO_INCREMENT values are assumed.
CREATE TEMPORARY TABLE _seed_preexisting_reservations (
    reservation_id INT UNSIGNED NOT NULL PRIMARY KEY
);

INSERT INTO _seed_preexisting_reservations (reservation_id)
SELECT existing_reservation.reservation_id
FROM _seed_reservations AS seed
INNER JOIN clients AS client
    ON client.email = seed.client_email
INNER JOIN reservations AS existing_reservation
    ON existing_reservation.client_id = client.client_id
   AND existing_reservation.check_in_date = seed.check_in_date
   AND existing_reservation.check_out_date = seed.check_out_date
   AND existing_reservation.guest_count = seed.guest_count;

INSERT INTO reservations
    (client_id, check_in_date, check_out_date, guest_count, reservation_status, created_at, cancelled_at)
SELECT
    client.client_id,
    seed.check_in_date,
    seed.check_out_date,
    seed.guest_count,
    'pending',
    TIMESTAMP(DATE_SUB(seed.check_in_date, INTERVAL 30 DAY)),
    NULL
FROM _seed_reservations AS seed
INNER JOIN clients AS client
    ON client.email = seed.client_email
WHERE NOT EXISTS (
    SELECT 1
    FROM reservations AS existing_reservation
    WHERE existing_reservation.client_id = client.client_id
      AND existing_reservation.check_in_date = seed.check_in_date
      AND existing_reservation.check_out_date = seed.check_out_date
    AND existing_reservation.guest_count = seed.guest_count
);

CREATE TEMPORARY TABLE _seed_reservation_map (
    seed_no TINYINT UNSIGNED NOT NULL PRIMARY KEY,
    reservation_id INT UNSIGNED NOT NULL
);

INSERT INTO _seed_reservation_map (seed_no, reservation_id)
SELECT seed.seed_no, MIN(reservation.reservation_id)
FROM _seed_reservations AS seed
INNER JOIN clients AS client
    ON client.email = seed.client_email
INNER JOIN reservations AS reservation
    ON reservation.client_id = client.client_id
   AND reservation.check_in_date = seed.check_in_date
   AND reservation.check_out_date = seed.check_out_date
   AND reservation.guest_count = seed.guest_count
GROUP BY seed.seed_no;

INSERT INTO reservation_rooms (reservation_id, room_id, booked_price_per_night)
SELECT
    reservation_map.reservation_id,
    room.room_id,
    room.base_price_per_night
FROM _seed_reservation_rooms AS seed_room
INNER JOIN _seed_reservation_map AS reservation_map
    ON reservation_map.seed_no = seed_room.seed_no
INNER JOIN _seed_rooms AS expected_room
    ON expected_room.room_number = seed_room.room_number
INNER JOIN room_types AS expected_type
    ON expected_type.type_name = expected_room.type_name
INNER JOIN rooms AS room
    ON room.room_number = seed_room.room_number
   AND room.room_type_id = expected_type.room_type_id
INNER JOIN reservations AS seed_reservation
    ON seed_reservation.reservation_id = reservation_map.reservation_id
WHERE room.operational_status <> 'out_of_service'
AND NOT EXISTS (
    SELECT 1
    FROM reservation_rooms AS existing_link
    WHERE existing_link.reservation_id = reservation_map.reservation_id
      AND existing_link.room_id = room.room_id
)
AND NOT EXISTS (
    SELECT 1
    FROM reservation_rooms AS conflicting_link
    INNER JOIN reservations AS conflicting_reservation
        ON conflicting_reservation.reservation_id = conflicting_link.reservation_id
    WHERE conflicting_link.room_id = room.room_id
      AND conflicting_reservation.reservation_id <> seed_reservation.reservation_id
      AND conflicting_reservation.reservation_status IN ('confirmed', 'completed')
      AND conflicting_reservation.check_in_date < seed_reservation.check_out_date
      AND conflicting_reservation.check_out_date > seed_reservation.check_in_date
);

CREATE TEMPORARY TABLE _seed_activatable_reservations (
    reservation_id INT UNSIGNED NOT NULL PRIMARY KEY
);

INSERT INTO _seed_activatable_reservations (reservation_id)
SELECT reservation_map.reservation_id
FROM _seed_reservation_map AS reservation_map
INNER JOIN _seed_reservations AS seed
    ON seed.seed_no = reservation_map.seed_no
INNER JOIN reservations AS reservation
    ON reservation.reservation_id = reservation_map.reservation_id
WHERE seed.reservation_status IN ('confirmed', 'completed')
  AND (
      SELECT COALESCE(SUM(room.max_capacity), 0)
      FROM reservation_rooms AS reserved_room
      INNER JOIN rooms AS room ON room.room_id = reserved_room.room_id
      WHERE reserved_room.reservation_id = reservation.reservation_id
  ) >= reservation.guest_count
  AND NOT EXISTS (
      SELECT 1
      FROM reservation_rooms AS own_room
      INNER JOIN reservation_rooms AS other_room
          ON other_room.room_id = own_room.room_id
         AND other_room.reservation_id <> reservation.reservation_id
      INNER JOIN reservations AS other_reservation
          ON other_reservation.reservation_id = other_room.reservation_id
         AND other_reservation.reservation_status IN ('confirmed', 'completed')
         AND reservation.check_in_date < other_reservation.check_out_date
         AND reservation.check_out_date > other_reservation.check_in_date
      WHERE own_room.reservation_id = reservation.reservation_id
  );

UPDATE reservations AS reservation
INNER JOIN _seed_reservation_map AS reservation_map
    ON reservation_map.reservation_id = reservation.reservation_id
INNER JOIN _seed_reservations AS seed
    ON seed.seed_no = reservation_map.seed_no
LEFT JOIN _seed_preexisting_reservations AS preexisting
    ON preexisting.reservation_id = reservation.reservation_id
LEFT JOIN _seed_activatable_reservations AS activatable
    ON activatable.reservation_id = reservation.reservation_id
SET reservation.reservation_status = seed.reservation_status,
    reservation.cancelled_at = CASE
        WHEN seed.reservation_status = 'cancelled'
            THEN TIMESTAMP(DATE_SUB(seed.check_in_date, INTERVAL 1 DAY))
        ELSE NULL
    END
WHERE preexisting.reservation_id IS NULL
  AND (
      seed.reservation_status IN ('pending', 'cancelled')
      OR activatable.reservation_id IS NOT NULL
  );

-- Service slots are inside the associated completed reservations.
INSERT INTO service_bookings
    (reservation_id, service_id, slot_start, slot_end, quantity, booked_unit_price)
SELECT
    reservation_map.reservation_id,
    service.service_id,
    TIMESTAMP(DATE_ADD(reservation.check_in_date, INTERVAL seed_booking.day_after_check_in DAY), seed_booking.starts_at),
    TIMESTAMP(DATE_ADD(reservation.check_in_date, INTERVAL seed_booking.day_after_check_in DAY), seed_booking.ends_at),
    seed_booking.quantity,
    service.price
FROM _seed_service_bookings AS seed_booking
INNER JOIN _seed_reservation_map AS reservation_map
    ON reservation_map.seed_no = seed_booking.seed_no
INNER JOIN reservations AS reservation
    ON reservation.reservation_id = reservation_map.reservation_id
INNER JOIN services AS service
    ON service.service_name = seed_booking.service_name
WHERE NOT EXISTS (
    SELECT 1
    FROM service_bookings AS existing_booking
    WHERE existing_booking.reservation_id = reservation_map.reservation_id
      AND existing_booking.service_id = service.service_id
      AND existing_booking.slot_start = TIMESTAMP(
          DATE_ADD(reservation.check_in_date, INTERVAL seed_booking.day_after_check_in DAY),
          seed_booking.starts_at
      )
);

-- Ten completed stays receive invoices. The first is fully paid, the second
-- partially paid, and the third due/unpaid. The remainder are fully paid.
INSERT INTO invoices (reservation_id, issued_at, status)
SELECT
    reservation_map.reservation_id,
    DATE_ADD(reservation.check_out_date, INTERVAL 1 DAY),
    CASE payment_case.payment_case
        WHEN 'partial' THEN 'partially_paid'
        WHEN 'due' THEN 'due'
        ELSE 'paid'
    END
FROM _seed_payment_cases AS payment_case
INNER JOIN _seed_reservation_map AS reservation_map
    ON reservation_map.seed_no = payment_case.seed_no
INNER JOIN reservations AS reservation
    ON reservation.reservation_id = reservation_map.reservation_id
WHERE NOT EXISTS (
    SELECT 1 FROM invoices AS existing_invoice WHERE existing_invoice.reservation_id = reservation_map.reservation_id
);

CREATE TEMPORARY TABLE _seed_invoice_map (
    seed_no TINYINT UNSIGNED NOT NULL PRIMARY KEY,
    invoice_id INT UNSIGNED NOT NULL
);

INSERT INTO _seed_invoice_map (seed_no, invoice_id)
SELECT payment_case.seed_no, MIN(invoice.invoice_id)
FROM _seed_payment_cases AS payment_case
INNER JOIN _seed_reservation_map AS reservation_map
    ON reservation_map.seed_no = payment_case.seed_no
INNER JOIN invoices AS invoice
    ON invoice.reservation_id = reservation_map.reservation_id
GROUP BY payment_case.seed_no;

-- Each reserved room gets its own preserved nightly-price invoice line.
INSERT INTO invoice_lines (invoice_id, line_type, description, quantity, unit_price, tax_rate)
SELECT
    invoice_map.invoice_id,
    'accommodation',
    CONCAT('Seed accommodation ', LPAD(seed_room.seed_no, 2, '0'), ' / ', room.room_number),
    DATEDIFF(reservation.check_out_date, reservation.check_in_date),
    reserved_room.booked_price_per_night,
    0.00
FROM _seed_reservation_rooms AS seed_room
INNER JOIN _seed_reservation_map AS reservation_map
    ON reservation_map.seed_no = seed_room.seed_no
INNER JOIN _seed_invoice_map AS invoice_map
    ON invoice_map.seed_no = seed_room.seed_no
INNER JOIN reservations AS reservation
    ON reservation.reservation_id = reservation_map.reservation_id
INNER JOIN rooms AS room
    ON room.room_number = seed_room.room_number
INNER JOIN reservation_rooms AS reserved_room
    ON reserved_room.reservation_id = reservation_map.reservation_id
   AND reserved_room.room_id = room.room_id
WHERE NOT EXISTS (
    SELECT 1
    FROM invoice_lines AS existing_line
    WHERE existing_line.invoice_id = invoice_map.invoice_id
      AND existing_line.description = CONCAT('Seed accommodation ', LPAD(seed_room.seed_no, 2, '0'), ' / ', room.room_number)
);

-- Service invoice lines use the booked unit price snapshot.
INSERT INTO invoice_lines (invoice_id, line_type, description, quantity, unit_price, tax_rate)
SELECT
    invoice_map.invoice_id,
    'service',
    CONCAT('Seed service: ', seed_booking.service_name),
    service_booking.quantity,
    service_booking.booked_unit_price,
    0.00
FROM _seed_service_bookings AS seed_booking
INNER JOIN _seed_reservation_map AS reservation_map
    ON reservation_map.seed_no = seed_booking.seed_no
INNER JOIN _seed_invoice_map AS invoice_map
    ON invoice_map.seed_no = seed_booking.seed_no
INNER JOIN reservations AS reservation
    ON reservation.reservation_id = reservation_map.reservation_id
INNER JOIN services AS service
    ON service.service_name = seed_booking.service_name
INNER JOIN service_bookings AS service_booking
    ON service_booking.reservation_id = reservation_map.reservation_id
   AND service_booking.service_id = service.service_id
   AND service_booking.slot_start = TIMESTAMP(
       DATE_ADD(reservation.check_in_date, INTERVAL seed_booking.day_after_check_in DAY),
       seed_booking.starts_at
   )
WHERE NOT EXISTS (
    SELECT 1
    FROM invoice_lines AS existing_line
    WHERE existing_line.invoice_id = invoice_map.invoice_id
      AND existing_line.description = CONCAT('Seed service: ', seed_booking.service_name)
);

-- Payment amounts are derived from itemized lines, including service charges.
-- The due case intentionally inserts no payment row.
INSERT INTO payments (invoice_id, payment_date, amount, method)
SELECT
    invoice_map.invoice_id,
    DATE_ADD(reservation.check_out_date, INTERVAL 1 DAY),
    CASE payment_case.payment_case
        WHEN 'partial' THEN ROUND(invoice_total.total_amount / 2, 2)
        ELSE invoice_total.total_amount
    END,
    CASE payment_case.payment_case
        WHEN 'partial' THEN 'mobile_money'
        ELSE 'card'
    END
FROM _seed_payment_cases AS payment_case
INNER JOIN _seed_invoice_map AS invoice_map
    ON invoice_map.seed_no = payment_case.seed_no
INNER JOIN _seed_reservation_map AS reservation_map
    ON reservation_map.seed_no = payment_case.seed_no
INNER JOIN reservations AS reservation
    ON reservation.reservation_id = reservation_map.reservation_id
INNER JOIN (
    SELECT
        line.invoice_id,
        SUM(line.quantity * line.unit_price * (1 + line.tax_rate / 100)) AS total_amount
    FROM invoice_lines AS line
    GROUP BY line.invoice_id
) AS invoice_total
    ON invoice_total.invoice_id = invoice_map.invoice_id
WHERE payment_case.payment_case <> 'due'
  AND invoice_total.total_amount > 0
  AND NOT EXISTS (
      SELECT 1
      FROM payments AS existing_payment
      WHERE existing_payment.invoice_id = invoice_map.invoice_id
                AND existing_payment.payment_date = DATE_ADD(reservation.check_out_date, INTERVAL 1 DAY)
        AND existing_payment.amount = CASE payment_case.payment_case
            WHEN 'partial' THEN ROUND(invoice_total.total_amount / 2, 2)
            ELSE invoice_total.total_amount
        END
        AND existing_payment.method = CASE payment_case.payment_case
            WHEN 'partial' THEN 'mobile_money'
            ELSE 'card'
        END
  );

-- Reviews are linked to completed reservations; the schema's unique reservation
-- key prevents a second review for the same stay.
INSERT INTO reviews (reservation_id, rating, comment, review_date)
SELECT
    reservation_map.reservation_id,
    seed_review.rating,
    seed_review.review_comment,
    DATE_ADD(reservation.check_out_date, INTERVAL 2 DAY)
FROM _seed_review_rows AS seed_review
INNER JOIN _seed_reservation_map AS reservation_map
    ON reservation_map.seed_no = seed_review.seed_no
INNER JOIN reservations AS reservation
    ON reservation.reservation_id = reservation_map.reservation_id
WHERE NOT EXISTS (
    SELECT 1 FROM reviews AS existing_review WHERE existing_review.reservation_id = reservation_map.reservation_id
);

COMMIT;

-- The following temporary staging tables disappear when this connection closes.