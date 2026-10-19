USE hotel_management;

DROP PROCEDURE IF EXISTS sp_expect_constraint_failure;

DELIMITER $$

CREATE PROCEDURE sp_expect_constraint_failure(
	IN p_test_name VARCHAR(120),
	IN p_statement TEXT
)
BEGIN
	DECLARE v_failed BOOLEAN DEFAULT FALSE;
	DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET v_failed = TRUE;

	SAVEPOINT expected_failure;
	SET @constraint_test_statement = p_statement;
	PREPARE constraint_test_statement FROM @constraint_test_statement;
	EXECUTE constraint_test_statement;
	DEALLOCATE PREPARE constraint_test_statement;
	ROLLBACK TO SAVEPOINT expected_failure;

	SELECT p_test_name AS test_name, IF(v_failed, 1, 0) AS passed;
END$$

DELIMITER ;

START TRANSACTION;

INSERT INTO room_types (type_name) VALUES ('Constraint Test Type');
SET @constraint_test_room_type_id = LAST_INSERT_ID();

INSERT INTO rooms (
	room_number,
	floor_number,
	room_type_id,
	max_capacity,
	base_price_per_night
)
VALUES ('CT-01', 99, @constraint_test_room_type_id, 2, 100.00);
SET @constraint_test_room_id = LAST_INSERT_ID();

INSERT INTO clients (last_name, first_name, phone, email)
VALUES ('Test', 'Constraint', '+00000000001', 'constraint-test@example.invalid');
SET @constraint_test_client_id = LAST_INSERT_ID();

INSERT INTO services (service_name, description, price, slot_capacity)
VALUES ('Constraint Test Service', 'Test fixture', 25.00, 1);
SET @constraint_test_service_id = LAST_INSERT_ID();

INSERT INTO service_opening_hours (service_id, day_of_week, opens_at, closes_at)
SELECT @constraint_test_service_id, day_number, '09:00:00', '17:00:00'
FROM (
	SELECT 1 AS day_number UNION ALL SELECT 2 UNION ALL SELECT 3
	UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7
) AS weekdays;

INSERT INTO reservations (
	client_id, check_in_date, check_out_date, guest_count, reservation_status
)
VALUES (
	@constraint_test_client_id,
	CURRENT_DATE() + INTERVAL 10 DAY,
	CURRENT_DATE() + INTERVAL 12 DAY,
	1,
	'pending'
);
SET @constraint_test_reservation_id = LAST_INSERT_ID();

INSERT INTO reservation_rooms (reservation_id, room_id, booked_price_per_night)
VALUES (@constraint_test_reservation_id, @constraint_test_room_id, 100.00);

UPDATE reservations
SET reservation_status = 'confirmed'
WHERE reservation_id = @constraint_test_reservation_id;

INSERT INTO service_bookings (
	reservation_id, service_id, slot_start, slot_end, quantity, booked_unit_price
)
VALUES (
	@constraint_test_reservation_id,
	@constraint_test_service_id,
	CURRENT_DATE() + INTERVAL 10 DAY + INTERVAL 10 HOUR,
	CURRENT_DATE() + INTERVAL 10 DAY + INTERVAL 11 HOUR,
	1,
	25.00
);

INSERT INTO invoices (reservation_id)
VALUES (@constraint_test_reservation_id);
SET @constraint_test_invoice_id = LAST_INSERT_ID();

INSERT INTO invoice_lines (
	invoice_id, line_type, description, quantity, unit_price, tax_rate
)
VALUES (@constraint_test_invoice_id, 'miscellaneous', 'Test charge', 1, 100.00, 0);
SET @constraint_test_invoice_line_id = LAST_INSERT_ID();

CALL sp_expect_constraint_failure(
	'Reject inserting an active reservation directly',
	CONCAT(
		'INSERT INTO reservations ',
		'(client_id, check_in_date, check_out_date, guest_count, reservation_status) VALUES (',
		@constraint_test_client_id,
		', CURRENT_DATE() + INTERVAL 10 DAY, CURRENT_DATE() + INTERVAL 12 DAY, 1, ''confirmed'')'
	)
);

INSERT INTO reservations (
	client_id, check_in_date, check_out_date, guest_count, reservation_status
)
VALUES (
	@constraint_test_client_id,
	CURRENT_DATE() + INTERVAL 10 DAY,
	CURRENT_DATE() + INTERVAL 12 DAY,
	1,
	'pending'
);
SET @constraint_test_overlap_id = LAST_INSERT_ID();

INSERT INTO reservation_rooms (reservation_id, room_id, booked_price_per_night)
VALUES (@constraint_test_overlap_id, @constraint_test_room_id, 100.00);

CALL sp_expect_constraint_failure(
	'Reject confirming overlapping reservation',
	CONCAT(
		'UPDATE reservations SET reservation_status = ''confirmed'' ',
		'WHERE reservation_id = ', @constraint_test_overlap_id
	)
);

INSERT INTO reservations (
	client_id, check_in_date, check_out_date, guest_count, reservation_status
)
VALUES (
	@constraint_test_client_id,
	CURRENT_DATE() + INTERVAL 20 DAY,
	CURRENT_DATE() + INTERVAL 22 DAY,
	3,
	'pending'
);
SET @constraint_test_capacity_id = LAST_INSERT_ID();

INSERT INTO reservation_rooms (reservation_id, room_id, booked_price_per_night)
VALUES (@constraint_test_capacity_id, @constraint_test_room_id, 100.00);

CALL sp_expect_constraint_failure(
	'Reject confirming reservation above room capacity',
	CONCAT(
		'UPDATE reservations SET reservation_status = ''confirmed'' ',
		'WHERE reservation_id = ', @constraint_test_capacity_id
	)
);

CALL sp_expect_constraint_failure(
	'Reject service booking outside opening hours',
	CONCAT(
		'INSERT INTO service_bookings ',
		'(reservation_id, service_id, slot_start, slot_end, quantity, booked_unit_price) VALUES (',
		@constraint_test_reservation_id, ', ', @constraint_test_service_id,
		', CURRENT_DATE() + INTERVAL 10 DAY + INTERVAL 18 HOUR, ',
		'CURRENT_DATE() + INTERVAL 10 DAY + INTERVAL 19 HOUR, 1, 25.00)'
	)
);

CALL sp_expect_constraint_failure(
	'Reject service slot over capacity',
	CONCAT(
		'INSERT INTO service_bookings ',
		'(reservation_id, service_id, slot_start, slot_end, quantity, booked_unit_price) VALUES (',
		@constraint_test_reservation_id, ', ', @constraint_test_service_id,
		', CURRENT_DATE() + INTERVAL 10 DAY + INTERVAL 10 HOUR, ',
		'CURRENT_DATE() + INTERVAL 10 DAY + INTERVAL 11 HOUR, 1, 25.00)'
	)
);

CALL sp_expect_constraint_failure(
	'Reject review before completed stay',
	CONCAT(
		'INSERT INTO reviews (reservation_id, rating, comment, review_date) VALUES (',
		@constraint_test_reservation_id, ', 5, ''Not checked out'', CURRENT_DATE())'
	)
);

CALL sp_record_payment(@constraint_test_invoice_id, 60.00, 'card');
SELECT
	'Partial payment updates invoice status' AS test_name,
	IF(status = 'partially_paid', 1, 0) AS passed
FROM invoices
WHERE invoice_id = @constraint_test_invoice_id;

CALL sp_expect_constraint_failure(
	'Reject payment above remaining balance',
	CONCAT(
		'CALL sp_record_payment(', @constraint_test_invoice_id, ', 50.00, ''card'')'
	)
);

CALL sp_expect_constraint_failure(
	'Reject invoice reduction below payments received',
	CONCAT(
		'UPDATE invoice_lines SET unit_price = 50.00 ',
		'WHERE invoice_line_id = ', @constraint_test_invoice_line_id
	)
);

CALL sp_record_payment(@constraint_test_invoice_id, 40.00, 'mobile_money');
SELECT
	'Full payment updates invoice status' AS test_name,
	IF(status = 'paid', 1, 0) AS passed
FROM invoices
WHERE invoice_id = @constraint_test_invoice_id;

ROLLBACK;
DROP PROCEDURE IF EXISTS sp_expect_constraint_failure;
