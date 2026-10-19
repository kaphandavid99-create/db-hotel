USE hotel_management;

DROP TRIGGER IF EXISTS bi_reservation_rooms_validate;
DROP TRIGGER IF EXISTS bu_reservation_rooms_validate;
DROP TRIGGER IF EXISTS bi_reservations_require_pending;
DROP TRIGGER IF EXISTS bu_reservations_validate_status;
DROP TRIGGER IF EXISTS bi_service_bookings_validate;
DROP TRIGGER IF EXISTS bu_service_bookings_validate;
DROP TRIGGER IF EXISTS bi_reviews_validate_completed_stay;
DROP TRIGGER IF EXISTS bu_reviews_validate_completed_stay;
DROP TRIGGER IF EXISTS bi_payments_validate_amount;
DROP TRIGGER IF EXISTS bu_payments_validate_amount;
DROP TRIGGER IF EXISTS bu_invoice_lines_prevent_underpayment;
DROP TRIGGER IF EXISTS bd_invoice_lines_prevent_underpayment;
DROP TRIGGER IF EXISTS ai_payments_refresh_invoice;
DROP TRIGGER IF EXISTS au_payments_refresh_invoice;
DROP TRIGGER IF EXISTS ad_payments_refresh_invoice;
DROP TRIGGER IF EXISTS ai_invoice_lines_refresh_invoice;
DROP TRIGGER IF EXISTS au_invoice_lines_refresh_invoice;
DROP TRIGGER IF EXISTS ad_invoice_lines_refresh_invoice;
DROP PROCEDURE IF EXISTS sp_refresh_invoice_status;
DROP PROCEDURE IF EXISTS sp_record_payment;

DELIMITER $$

CREATE PROCEDURE sp_refresh_invoice_status(IN p_invoice_id INT UNSIGNED)
BEGIN
		DECLARE v_invoice_total DECIMAL(18, 2) DEFAULT 0;
		DECLARE v_paid_total DECIMAL(18, 2) DEFAULT 0;

		SELECT COALESCE(SUM(quantity * unit_price * (1 + tax_rate / 100)), 0)
			INTO v_invoice_total
			FROM invoice_lines
		 WHERE invoice_id = p_invoice_id;

		SELECT COALESCE(SUM(amount), 0)
			INTO v_paid_total
			FROM payments
		 WHERE invoice_id = p_invoice_id;

		UPDATE invoices
			 SET status = CASE
					 WHEN v_paid_total = 0 THEN 'due'
					 WHEN v_paid_total >= v_invoice_total THEN 'paid'
					 ELSE 'partially_paid'
			 END
		 WHERE invoice_id = p_invoice_id;
END$$

CREATE PROCEDURE sp_record_payment(
		IN p_invoice_id INT UNSIGNED,
		IN p_amount DECIMAL(10, 2),
		IN p_method VARCHAR(20)
)
BEGIN
		IF p_amount IS NULL OR p_amount <= 0 THEN
				SIGNAL SQLSTATE '45000'
						SET MESSAGE_TEXT = 'Payment amount must be greater than zero';
		END IF;

		INSERT INTO payments (invoice_id, amount, method)
		VALUES (p_invoice_id, p_amount, p_method);
END$$

CREATE TRIGGER bi_reservation_rooms_validate
BEFORE INSERT ON reservation_rooms
FOR EACH ROW
BEGIN
		DECLARE v_locked_room_id INT UNSIGNED;

		SELECT room_id
			INTO v_locked_room_id
			FROM rooms
		 WHERE room_id = NEW.room_id
		 FOR UPDATE;

		IF EXISTS (
				SELECT 1
					FROM reservations AS new_reservation
					JOIN reservations AS existing_reservation
						ON existing_reservation.reservation_id <> new_reservation.reservation_id
					 AND existing_reservation.reservation_status IN ('confirmed', 'completed')
					 AND new_reservation.check_in_date < existing_reservation.check_out_date
					 AND new_reservation.check_out_date > existing_reservation.check_in_date
					JOIN reservation_rooms AS existing_room
						ON existing_room.reservation_id = existing_reservation.reservation_id
					 AND existing_room.room_id = NEW.room_id
				 WHERE new_reservation.reservation_id = NEW.reservation_id
					 AND new_reservation.reservation_status IN ('confirmed', 'completed')
		) THEN
				SIGNAL SQLSTATE '45000'
						SET MESSAGE_TEXT = 'Room is already assigned during an overlapping active stay';
		END IF;
END$$

CREATE TRIGGER bu_reservation_rooms_validate
BEFORE UPDATE ON reservation_rooms
FOR EACH ROW
BEGIN
		DECLARE v_locked_room_id INT UNSIGNED;

		SELECT room_id
			INTO v_locked_room_id
			FROM rooms
		 WHERE room_id = NEW.room_id
		 FOR UPDATE;

		IF EXISTS (
				SELECT 1
					FROM reservations AS new_reservation
					JOIN reservations AS existing_reservation
						ON existing_reservation.reservation_id <> NEW.reservation_id
					 AND existing_reservation.reservation_status IN ('confirmed', 'completed')
					 AND new_reservation.check_in_date < existing_reservation.check_out_date
					 AND new_reservation.check_out_date > existing_reservation.check_in_date
					JOIN reservation_rooms AS existing_room
						ON existing_room.reservation_id = existing_reservation.reservation_id
					 AND existing_room.room_id = NEW.room_id
				 WHERE new_reservation.reservation_id = NEW.reservation_id
					 AND new_reservation.reservation_status IN ('confirmed', 'completed')
		) THEN
				SIGNAL SQLSTATE '45000'
						SET MESSAGE_TEXT = 'Room is already assigned during an overlapping active stay';
		END IF;
END$$

CREATE TRIGGER bi_reservations_require_pending
BEFORE INSERT ON reservations
FOR EACH ROW
BEGIN
	IF NEW.reservation_status IN ('confirmed', 'completed') THEN
		SIGNAL SQLSTATE '45000'
			SET MESSAGE_TEXT = 'Create reservations as pending, assign rooms, then activate them';
	END IF;
END$$

CREATE TRIGGER bu_reservations_validate_status
BEFORE UPDATE ON reservations
FOR EACH ROW
BEGIN
		DECLARE v_room_capacity INT UNSIGNED DEFAULT 0;

		IF NEW.reservation_status IN ('confirmed', 'completed') THEN
				SELECT COALESCE(SUM(room.max_capacity), 0)
					INTO v_room_capacity
					FROM reservation_rooms AS reserved_room
					JOIN rooms AS room ON room.room_id = reserved_room.room_id
				 WHERE reserved_room.reservation_id = NEW.reservation_id;

				IF v_room_capacity < NEW.guest_count THEN
						SIGNAL SQLSTATE '45000'
								SET MESSAGE_TEXT = 'Assigned room capacity must cover the reservation guest count';
				END IF;

				IF NEW.reservation_status = 'completed' AND NEW.check_out_date > CURRENT_DATE() THEN
						SIGNAL SQLSTATE '45000'
								SET MESSAGE_TEXT = 'A stay cannot be completed before its checkout date';
				END IF;

				IF EXISTS (
						SELECT 1
							FROM reservation_rooms AS new_room
							JOIN reservation_rooms AS other_room
								ON other_room.room_id = new_room.room_id
							 AND other_room.reservation_id <> NEW.reservation_id
							JOIN reservations AS other_reservation
								ON other_reservation.reservation_id = other_room.reservation_id
							 AND other_reservation.reservation_status IN ('confirmed', 'completed')
							 AND NEW.check_in_date < other_reservation.check_out_date
							 AND NEW.check_out_date > other_reservation.check_in_date
						 WHERE new_room.reservation_id = NEW.reservation_id
				) THEN
						SIGNAL SQLSTATE '45000'
								SET MESSAGE_TEXT = 'Reservation overlaps another active booking for an assigned room';
				END IF;
		END IF;
END$$

CREATE TRIGGER bi_service_bookings_validate
BEFORE INSERT ON service_bookings
FOR EACH ROW
BEGIN
		DECLARE v_locked_service_id INT UNSIGNED;

		SELECT service_id
			INTO v_locked_service_id
			FROM services
		 WHERE service_id = NEW.service_id
		 FOR UPDATE;

		IF NOT EXISTS (
				SELECT 1
					FROM reservations AS reservation
					JOIN service_opening_hours AS hours
						ON hours.service_id = NEW.service_id
					 AND hours.day_of_week = WEEKDAY(NEW.slot_start) + 1
				 WHERE reservation.reservation_id = NEW.reservation_id
					 AND reservation.reservation_status IN ('confirmed', 'completed')
					 AND NEW.slot_start < NEW.slot_end
					 AND DATE(NEW.slot_start) = DATE(NEW.slot_end)
					 AND NEW.slot_start >= reservation.check_in_date
					 AND NEW.slot_end <= reservation.check_out_date
					 AND TIME(NEW.slot_start) >= hours.opens_at
					 AND TIME(NEW.slot_end) <= hours.closes_at
		) THEN
				SIGNAL SQLSTATE '45000'
						SET MESSAGE_TEXT = 'Service booking must fit an active stay and that service opening hours';
		END IF;

		IF (
				SELECT COALESCE(SUM(existing_booking.quantity), 0)
					FROM service_bookings AS existing_booking
				 WHERE existing_booking.service_id = NEW.service_id
					 AND existing_booking.slot_start < NEW.slot_end
					 AND existing_booking.slot_end > NEW.slot_start
		) + NEW.quantity > (
				SELECT service.slot_capacity
					FROM services AS service
				 WHERE service.service_id = NEW.service_id
		) THEN
				SIGNAL SQLSTATE '45000'
						SET MESSAGE_TEXT = 'Service slot capacity would be exceeded';
		END IF;
END$$

CREATE TRIGGER bu_service_bookings_validate
BEFORE UPDATE ON service_bookings
FOR EACH ROW
BEGIN
		DECLARE v_locked_service_id INT UNSIGNED;

		SELECT service_id
			INTO v_locked_service_id
			FROM services
		 WHERE service_id = NEW.service_id
		 FOR UPDATE;

		IF NOT EXISTS (
				SELECT 1
					FROM reservations AS reservation
					JOIN service_opening_hours AS hours
						ON hours.service_id = NEW.service_id
					 AND hours.day_of_week = WEEKDAY(NEW.slot_start) + 1
				 WHERE reservation.reservation_id = NEW.reservation_id
					 AND reservation.reservation_status IN ('confirmed', 'completed')
					 AND NEW.slot_start < NEW.slot_end
					 AND DATE(NEW.slot_start) = DATE(NEW.slot_end)
					 AND NEW.slot_start >= reservation.check_in_date
					 AND NEW.slot_end <= reservation.check_out_date
					 AND TIME(NEW.slot_start) >= hours.opens_at
					 AND TIME(NEW.slot_end) <= hours.closes_at
		) THEN
				SIGNAL SQLSTATE '45000'
						SET MESSAGE_TEXT = 'Service booking must fit an active stay and that service opening hours';
		END IF;

		IF (
				SELECT COALESCE(SUM(existing_booking.quantity), 0)
					FROM service_bookings AS existing_booking
				 WHERE existing_booking.service_id = NEW.service_id
					 AND existing_booking.service_booking_id <> OLD.service_booking_id
					 AND existing_booking.slot_start < NEW.slot_end
					 AND existing_booking.slot_end > NEW.slot_start
		) + NEW.quantity > (
				SELECT service.slot_capacity
					FROM services AS service
				 WHERE service.service_id = NEW.service_id
		) THEN
				SIGNAL SQLSTATE '45000'
						SET MESSAGE_TEXT = 'Service slot capacity would be exceeded';
		END IF;
END$$

CREATE TRIGGER bi_reviews_validate_completed_stay
BEFORE INSERT ON reviews
FOR EACH ROW
BEGIN
		IF NOT EXISTS (
				SELECT 1
					FROM reservations AS reservation
				 WHERE reservation.reservation_id = NEW.reservation_id
					 AND reservation.reservation_status = 'completed'
					 AND reservation.check_out_date <= CURRENT_DATE()
		) THEN
				SIGNAL SQLSTATE '45000'
						SET MESSAGE_TEXT = 'Only a completed stay may be reviewed';
		END IF;
END$$


CREATE TRIGGER bu_reviews_validate_completed_stay
BEFORE UPDATE ON reviews
FOR EACH ROW
BEGIN
		IF NOT EXISTS (
			SELECT 1
			  FROM reservations AS reservation
			 WHERE reservation.reservation_id = NEW.reservation_id
			   AND reservation.reservation_status = 'completed'
			   AND reservation.check_out_date <= CURRENT_DATE()
		) THEN
			SIGNAL SQLSTATE '45000'
				SET MESSAGE_TEXT = 'Only a completed stay may be reviewed';
		END IF;
	END$$


CREATE TRIGGER bu_invoice_lines_prevent_underpayment
BEFORE UPDATE ON invoice_lines
FOR EACH ROW
BEGIN
		DECLARE v_paid_total DECIMAL(18, 2) DEFAULT 0;
		DECLARE v_remaining_lines_total DECIMAL(18, 2) DEFAULT 0;

		SELECT COALESCE(SUM(amount), 0)
		  INTO v_paid_total
		  FROM payments
		 WHERE invoice_id = OLD.invoice_id;

		SELECT COALESCE(SUM(quantity * unit_price * (1 + tax_rate / 100)), 0)
		  INTO v_remaining_lines_total
		  FROM invoice_lines
		 WHERE invoice_id = OLD.invoice_id
		   AND invoice_line_id <> OLD.invoice_line_id;

		IF OLD.invoice_id = NEW.invoice_id THEN
			SET v_remaining_lines_total = v_remaining_lines_total
				+ NEW.quantity * NEW.unit_price * (1 + NEW.tax_rate / 100);
		END IF;

		IF v_paid_total > v_remaining_lines_total THEN
			SIGNAL SQLSTATE '45000'
				SET MESSAGE_TEXT = 'Invoice lines cannot be reduced below payments already received';
		END IF;
	END$$


CREATE TRIGGER bd_invoice_lines_prevent_underpayment
BEFORE DELETE ON invoice_lines
FOR EACH ROW
BEGIN
		DECLARE v_paid_total DECIMAL(18, 2) DEFAULT 0;
		DECLARE v_remaining_lines_total DECIMAL(18, 2) DEFAULT 0;

		SELECT COALESCE(SUM(amount), 0)
		  INTO v_paid_total
		  FROM payments
		 WHERE invoice_id = OLD.invoice_id;

		SELECT COALESCE(SUM(quantity * unit_price * (1 + tax_rate / 100)), 0)
		  INTO v_remaining_lines_total
		  FROM invoice_lines
		 WHERE invoice_id = OLD.invoice_id
		   AND invoice_line_id <> OLD.invoice_line_id;

		IF v_paid_total > v_remaining_lines_total THEN
			SIGNAL SQLSTATE '45000'
				SET MESSAGE_TEXT = 'Invoice lines cannot be reduced below payments already received';
		END IF;
	END$$

CREATE TRIGGER bi_payments_validate_amount
BEFORE INSERT ON payments
FOR EACH ROW
BEGIN
		DECLARE v_locked_invoice_id INT UNSIGNED;
		DECLARE v_invoice_total DECIMAL(18, 2) DEFAULT 0;
		DECLARE v_paid_total DECIMAL(18, 2) DEFAULT 0;

		SELECT invoice_id INTO v_locked_invoice_id
			FROM invoices
		 WHERE invoice_id = NEW.invoice_id
		 FOR UPDATE;

		SELECT COALESCE(SUM(quantity * unit_price * (1 + tax_rate / 100)), 0)
			INTO v_invoice_total
			FROM invoice_lines
		 WHERE invoice_id = NEW.invoice_id;

		SELECT COALESCE(SUM(amount), 0)
			INTO v_paid_total
			FROM payments
		 WHERE invoice_id = NEW.invoice_id;

		IF v_paid_total + NEW.amount > v_invoice_total THEN
				SIGNAL SQLSTATE '45000'
						SET MESSAGE_TEXT = 'Payment would exceed the invoice total';
		END IF;
END$$

CREATE TRIGGER bu_payments_validate_amount
BEFORE UPDATE ON payments
FOR EACH ROW
BEGIN
		DECLARE v_locked_invoice_id INT UNSIGNED;
		DECLARE v_invoice_total DECIMAL(18, 2) DEFAULT 0;
		DECLARE v_paid_total DECIMAL(18, 2) DEFAULT 0;

		SELECT invoice_id INTO v_locked_invoice_id
			FROM invoices
		 WHERE invoice_id = NEW.invoice_id
		 FOR UPDATE;

		SELECT COALESCE(SUM(quantity * unit_price * (1 + tax_rate / 100)), 0)
			INTO v_invoice_total
			FROM invoice_lines
		 WHERE invoice_id = NEW.invoice_id;

		SELECT COALESCE(SUM(amount), 0)
			INTO v_paid_total
			FROM payments
		 WHERE invoice_id = NEW.invoice_id
			 AND payment_id <> OLD.payment_id;

		IF v_paid_total + NEW.amount > v_invoice_total THEN
				SIGNAL SQLSTATE '45000'
						SET MESSAGE_TEXT = 'Payment would exceed the invoice total';
		END IF;
END$$

CREATE TRIGGER ai_payments_refresh_invoice
AFTER INSERT ON payments
FOR EACH ROW
BEGIN
		CALL sp_refresh_invoice_status(NEW.invoice_id);
END$$

CREATE TRIGGER au_payments_refresh_invoice
AFTER UPDATE ON payments
FOR EACH ROW
BEGIN
		CALL sp_refresh_invoice_status(OLD.invoice_id);
		IF NEW.invoice_id <> OLD.invoice_id THEN
				CALL sp_refresh_invoice_status(NEW.invoice_id);
		END IF;
END$$

CREATE TRIGGER ad_payments_refresh_invoice
AFTER DELETE ON payments
FOR EACH ROW
BEGIN
		CALL sp_refresh_invoice_status(OLD.invoice_id);
END$$

CREATE TRIGGER ai_invoice_lines_refresh_invoice
AFTER INSERT ON invoice_lines
FOR EACH ROW
BEGIN
		CALL sp_refresh_invoice_status(NEW.invoice_id);
END$$

CREATE TRIGGER au_invoice_lines_refresh_invoice
AFTER UPDATE ON invoice_lines
FOR EACH ROW
BEGIN
		CALL sp_refresh_invoice_status(OLD.invoice_id);
		IF NEW.invoice_id <> OLD.invoice_id THEN
				CALL sp_refresh_invoice_status(NEW.invoice_id);
		END IF;
END$$

CREATE TRIGGER ad_invoice_lines_refresh_invoice
AFTER DELETE ON invoice_lines
FOR EACH ROW
BEGIN
		CALL sp_refresh_invoice_status(OLD.invoice_id);
END$$

DELIMITER ;
