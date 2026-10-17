USE hotel_management;

-- Run after sql/02_seed_data.sql. Each result row reports PASS (1) or FAIL (0).
-- The seed is identified by its reserved .invalid client email namespace.
WITH
invoice_line_totals AS (
    SELECT
        line.invoice_id,
        SUM(line.quantity * line.unit_price * (1 + line.tax_rate / 100)) AS invoice_total
    FROM invoice_lines AS line
    GROUP BY line.invoice_id
),
payment_totals AS (
    SELECT payment.invoice_id, SUM(payment.amount) AS paid_total
    FROM payments AS payment
    GROUP BY payment.invoice_id
),
seed_invoice_totals AS (
    SELECT
        invoice.invoice_id,
        invoice.status,
        COALESCE(line_total.invoice_total, 0) AS invoice_total,
        COALESCE(payment_total.paid_total, 0) AS paid_total
    FROM invoices AS invoice
    INNER JOIN reservations AS reservation
        ON reservation.reservation_id = invoice.reservation_id
    INNER JOIN clients AS client
        ON client.client_id = reservation.client_id
       AND client.email LIKE 'seed.client%@dbhotel.invalid'
    LEFT JOIN invoice_line_totals AS line_total
        ON line_total.invoice_id = invoice.invoice_id
    LEFT JOIN payment_totals AS payment_total
        ON payment_total.invoice_id = invoice.invoice_id
),
services_with_variable_hours AS (
    SELECT hours.service_id
    FROM service_opening_hours AS hours
    GROUP BY hours.service_id
    HAVING COUNT(DISTINCT hours.opens_at) > 1
        OR COUNT(DISTINCT hours.closes_at) > 1
),
multi_room_seed_reservations AS (
    SELECT reservation.reservation_id
    FROM reservations AS reservation
    INNER JOIN clients AS client
        ON client.client_id = reservation.client_id
       AND client.email LIKE 'seed.client%@dbhotel.invalid'
    INNER JOIN reservation_rooms AS reserved_room
        ON reserved_room.reservation_id = reservation.reservation_id
    GROUP BY reservation.reservation_id
    HAVING COUNT(*) >= 2
),
overlapping_seed_room_assignments AS (
    SELECT first_reservation.reservation_id AS first_id, second_reservation.reservation_id AS second_id
    FROM reservation_rooms AS first_room
    INNER JOIN reservations AS first_reservation
        ON first_reservation.reservation_id = first_room.reservation_id
       AND first_reservation.reservation_status IN ('confirmed', 'completed')
    INNER JOIN clients AS first_client
        ON first_client.client_id = first_reservation.client_id
    INNER JOIN reservation_rooms AS second_room
        ON second_room.room_id = first_room.room_id
       AND second_room.reservation_id > first_room.reservation_id
    INNER JOIN reservations AS second_reservation
        ON second_reservation.reservation_id = second_room.reservation_id
       AND second_reservation.reservation_status IN ('confirmed', 'completed')
    INNER JOIN clients AS second_client
        ON second_client.client_id = second_reservation.client_id
    WHERE first_reservation.check_in_date < second_reservation.check_out_date
      AND second_reservation.check_in_date < first_reservation.check_out_date
      AND (
          first_client.email LIKE 'seed.client%@dbhotel.invalid'
          OR second_client.email LIKE 'seed.client%@dbhotel.invalid'
      )
),
seed_reservations_without_rooms AS (
    SELECT reservation.reservation_id
    FROM reservations AS reservation
    INNER JOIN clients AS client
        ON client.client_id = reservation.client_id
       AND client.email LIKE 'seed.client%@dbhotel.invalid'
    WHERE NOT EXISTS (
        SELECT 1
        FROM reservation_rooms AS reserved_room
        WHERE reserved_room.reservation_id = reservation.reservation_id
    )
),
seed_reservations_over_capacity AS (
    SELECT reservation.reservation_id
    FROM reservations AS reservation
    INNER JOIN clients AS client
        ON client.client_id = reservation.client_id
       AND client.email LIKE 'seed.client%@dbhotel.invalid'
    INNER JOIN reservation_rooms AS reserved_room
        ON reserved_room.reservation_id = reservation.reservation_id
    INNER JOIN rooms AS room
        ON room.room_id = reserved_room.room_id
    GROUP BY reservation.reservation_id, reservation.guest_count
    HAVING reservation.guest_count > SUM(room.max_capacity)
),
invalid_seed_service_bookings AS (
    SELECT service_booking.service_booking_id
    FROM service_bookings AS service_booking
    INNER JOIN reservations AS reservation
        ON reservation.reservation_id = service_booking.reservation_id
    INNER JOIN clients AS client
        ON client.client_id = reservation.client_id
       AND client.email LIKE 'seed.client%@dbhotel.invalid'
    INNER JOIN services AS service
        ON service.service_id = service_booking.service_id
    LEFT JOIN service_opening_hours AS opening_hours
        ON opening_hours.service_id = service.service_id
       AND opening_hours.day_of_week = WEEKDAY(service_booking.slot_start) + 1
    WHERE service_booking.slot_start < reservation.check_in_date
       OR service_booking.slot_end > reservation.check_out_date
       OR opening_hours.service_id IS NULL
       OR TIME(service_booking.slot_start) < opening_hours.opens_at
       OR TIME(service_booking.slot_end) > opening_hours.closes_at
),
invalid_seed_service_invoice_lines AS (
    SELECT service_booking.service_booking_id
    FROM service_bookings AS service_booking
    INNER JOIN reservations AS reservation
        ON reservation.reservation_id = service_booking.reservation_id
    INNER JOIN clients AS client
        ON client.client_id = reservation.client_id
       AND client.email LIKE 'seed.client%@dbhotel.invalid'
    INNER JOIN services AS service
        ON service.service_id = service_booking.service_id
    INNER JOIN invoices AS invoice
        ON invoice.reservation_id = reservation.reservation_id
    LEFT JOIN invoice_lines AS invoice_line
        ON invoice_line.invoice_id = invoice.invoice_id
       AND invoice_line.description = CONCAT('Seed service: ', service.service_name)
    WHERE invoice_line.invoice_line_id IS NULL
       OR invoice_line.quantity <> service_booking.quantity
       OR invoice_line.unit_price <> service_booking.booked_unit_price
)
SELECT
    'At least 10 seeded clients' AS test_name,
    CAST(COUNT(*) AS CHAR) AS actual_value,
    '>= 10' AS expected,
    COUNT(*) >= 10 AS passed
FROM clients
WHERE email LIKE 'seed.client%@dbhotel.invalid'
UNION ALL
SELECT
    'At least one seeded client has no reservations',
    CAST(COUNT(*) AS CHAR),
    '>= 1',
    COUNT(*) >= 1
FROM clients AS client
WHERE client.email LIKE 'seed.client%@dbhotel.invalid'
  AND NOT EXISTS (
      SELECT 1 FROM reservations AS reservation WHERE reservation.client_id = client.client_id
  )
UNION ALL
SELECT
    'At least 20 seeded reservations',
    CAST(COUNT(*) AS CHAR),
    '>= 20',
    COUNT(*) >= 20
FROM reservations AS reservation
INNER JOIN clients AS client
    ON client.client_id = reservation.client_id
WHERE client.email LIKE 'seed.client%@dbhotel.invalid'
UNION ALL
SELECT
    'Seed includes cancelled reservations',
    CAST(COUNT(*) AS CHAR),
    '>= 1',
    COUNT(*) >= 1
FROM reservations AS reservation
INNER JOIN clients AS client ON client.client_id = reservation.client_id
WHERE client.email LIKE 'seed.client%@dbhotel.invalid'
  AND reservation.reservation_status = 'cancelled'
UNION ALL
SELECT
    'Seed includes pending reservations',
    CAST(COUNT(*) AS CHAR),
    '>= 1',
    COUNT(*) >= 1
FROM reservations AS reservation
INNER JOIN clients AS client ON client.client_id = reservation.client_id
WHERE client.email LIKE 'seed.client%@dbhotel.invalid'
  AND reservation.reservation_status = 'pending'
UNION ALL
SELECT
    'Seed includes completed reservations',
    CAST(COUNT(*) AS CHAR),
    '>= 1',
    COUNT(*) >= 1
FROM reservations AS reservation
INNER JOIN clients AS client ON client.client_id = reservation.client_id
WHERE client.email LIKE 'seed.client%@dbhotel.invalid'
  AND reservation.reservation_status = 'completed'
UNION ALL
SELECT
    'At least one seed reservation has multiple rooms',
    CAST(COUNT(*) AS CHAR),
    '>= 1',
    COUNT(*) >= 1
FROM multi_room_seed_reservations
UNION ALL
SELECT
    'No overlapping confirmed/completed room assignments involving seed data',
    CAST(COUNT(*) AS CHAR),
    '0',
    COUNT(*) = 0
FROM overlapping_seed_room_assignments
UNION ALL
SELECT
    'Every seeded reservation has at least one room',
    CAST(COUNT(*) AS CHAR),
    '0 unassigned',
    COUNT(*) = 0
FROM seed_reservations_without_rooms
UNION ALL
SELECT
    'Seed guest counts do not exceed booked room capacity',
    CAST(COUNT(*) AS CHAR),
    '0 over-capacity',
    COUNT(*) = 0
FROM seed_reservations_over_capacity
UNION ALL
SELECT
    'At least four seeded services',
    CAST(COUNT(*) AS CHAR),
    '>= 4',
    COUNT(*) >= 4
FROM services
WHERE service_name LIKE 'Seed %'
UNION ALL
SELECT
    'At least four seeded services have varying hours',
    CAST(COUNT(*) AS CHAR),
    '>= 4',
    COUNT(*) >= 4
FROM services_with_variable_hours AS variable_hours
INNER JOIN services AS service
    ON service.service_id = variable_hours.service_id
WHERE service.service_name LIKE 'Seed %'
UNION ALL
SELECT
    'Seed spa is closed one day per week',
    CAST(COUNT(*) AS CHAR),
    '6 open days',
    COUNT(*) = 6
FROM service_opening_hours AS hours
INNER JOIN services AS service ON service.service_id = hours.service_id
WHERE service.service_name = 'Seed Spa Session'
UNION ALL
SELECT
        'Seed spa is closed Sunday',
        CAST(COUNT(*) AS CHAR),
        '0 Sunday hours',
        COUNT(*) = 0
FROM service_opening_hours AS hours
INNER JOIN services AS service ON service.service_id = hours.service_id
WHERE service.service_name = 'Seed Spa Session'
    AND hours.day_of_week = 7
UNION ALL
SELECT
    'At least six seeded service bookings',
    CAST(COUNT(*) AS CHAR),
    '>= 6',
    COUNT(*) >= 6
FROM service_bookings AS service_booking
INNER JOIN reservations AS reservation ON reservation.reservation_id = service_booking.reservation_id
INNER JOIN clients AS client ON client.client_id = reservation.client_id
WHERE client.email LIKE 'seed.client%@dbhotel.invalid'
UNION ALL
SELECT
    'Seed service bookings fit stay dates and opening hours',
    CAST(COUNT(*) AS CHAR),
    '0 invalid',
    COUNT(*) = 0
FROM invalid_seed_service_bookings
UNION ALL
SELECT
    'Seed service invoice lines match booked quantity and price',
    CAST(COUNT(*) AS CHAR),
    '0 mismatches',
    COUNT(*) = 0
FROM invalid_seed_service_invoice_lines
UNION ALL
SELECT
    'At least ten seeded invoices',
    CAST(COUNT(*) AS CHAR),
    '>= 10',
    COUNT(*) >= 10
FROM invoices AS invoice
INNER JOIN reservations AS reservation ON reservation.reservation_id = invoice.reservation_id
INNER JOIN clients AS client ON client.client_id = reservation.client_id
WHERE client.email LIKE 'seed.client%@dbhotel.invalid'
UNION ALL
SELECT
    'At least one fully paid seeded invoice',
    CAST(COUNT(*) AS CHAR),
    '>= 1',
    COUNT(*) >= 1
FROM seed_invoice_totals
WHERE status = 'paid' AND paid_total >= invoice_total AND paid_total > 0
UNION ALL
SELECT
    'At least one partially paid seeded invoice',
    CAST(COUNT(*) AS CHAR),
    '>= 1',
    COUNT(*) >= 1
FROM seed_invoice_totals
WHERE status = 'partially_paid' AND paid_total > 0 AND paid_total < invoice_total
UNION ALL
SELECT
    'At least one due seeded invoice with no payment',
    CAST(COUNT(*) AS CHAR),
    '>= 1',
    COUNT(*) >= 1
FROM seed_invoice_totals
WHERE status = 'due' AND paid_total = 0
UNION ALL
SELECT
    'At least six seeded reviews',
    CAST(COUNT(*) AS CHAR),
    '>= 6',
    COUNT(*) >= 6
FROM reviews AS review
INNER JOIN reservations AS reservation ON reservation.reservation_id = review.reservation_id
INNER JOIN clients AS client ON client.client_id = reservation.client_id
WHERE client.email LIKE 'seed.client%@dbhotel.invalid'
UNION ALL
SELECT
    'Seed review ratings span 1 through 5',
    CONCAT(MIN(review.rating), ' .. ', MAX(review.rating)),
    '1 .. 5',
    COALESCE(MIN(review.rating) = 1 AND MAX(review.rating) = 5, 0)
FROM reviews AS review
INNER JOIN reservations AS reservation ON reservation.reservation_id = review.reservation_id
INNER JOIN clients AS client ON client.client_id = reservation.client_id
WHERE client.email LIKE 'seed.client%@dbhotel.invalid';