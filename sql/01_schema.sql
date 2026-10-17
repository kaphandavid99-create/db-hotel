CREATE DATABASE hotel_management;
USE hotel_management;
SHOW DATABASES;

-- =====================================================
-- HOTEL MANAGEMENT DATABASE
-- File: 01_schema.sql
-- Deliverable: L3 - Table creation
-- MySQL 8 / InnoDB
-- =====================================================

USE hotel_management;

-- 1. ROOM TYPES
-- BR-01: Each room belongs to a type.

CREATE TABLE room_types (
    room_type_id SMALLINT UNSIGNED AUTO_INCREMENT,
    type_name VARCHAR(40) NOT NULL,

    CONSTRAINT pk_room_types
        PRIMARY KEY (room_type_id),

    CONSTRAINT uq_room_types_name
        UNIQUE (type_name)
) ENGINE = InnoDB;


-- 2. ROOMS
-- BR-01: Unique room number, floor, type,
-- maximum capacity and base nightly price.
-- BR-03: Operational status is not date availability.

CREATE TABLE rooms (
    room_id INT UNSIGNED AUTO_INCREMENT,
    room_number VARCHAR(10) NOT NULL,
    floor_number SMALLINT NOT NULL,
    room_type_id SMALLINT UNSIGNED NOT NULL,
    max_capacity TINYINT UNSIGNED NOT NULL,
    base_price_per_night DECIMAL(10,2) NOT NULL,
    operational_status ENUM(
        'available',
        'occupied',
        'being_cleaned',
        'out_of_service'
    ) NOT NULL DEFAULT 'available',

    CONSTRAINT pk_rooms
        PRIMARY KEY (room_id),

    CONSTRAINT uq_rooms_number
        UNIQUE (room_number),

    CONSTRAINT chk_rooms_capacity
        CHECK (max_capacity > 0),

    CONSTRAINT chk_rooms_price
        CHECK (base_price_per_night >= 0),

    CONSTRAINT fk_rooms_type
        FOREIGN KEY (room_type_id)
        REFERENCES room_types(room_type_id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE
) ENGINE = InnoDB;


-- 3. AMENITIES
-- BR-02: An amenity may apply to several rooms.

CREATE TABLE amenities (
    amenity_id SMALLINT UNSIGNED AUTO_INCREMENT,
    amenity_name VARCHAR(60) NOT NULL,

    CONSTRAINT pk_amenities
        PRIMARY KEY (amenity_id),

    CONSTRAINT uq_amenities_name
        UNIQUE (amenity_name)
) ENGINE = InnoDB;


-- 4. ROOM_AMENITIES
-- BR-02: Resolves the many-to-many relationship
-- between rooms and amenities.

CREATE TABLE room_amenities (
    room_id INT UNSIGNED NOT NULL,
    amenity_id SMALLINT UNSIGNED NOT NULL,

    CONSTRAINT pk_room_amenities
        PRIMARY KEY (room_id, amenity_id),

    CONSTRAINT fk_room_amenities_room
        FOREIGN KEY (room_id)
        REFERENCES rooms(room_id)
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    CONSTRAINT fk_room_amenities_amenity
        FOREIGN KEY (amenity_id)
        REFERENCES amenities(amenity_id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE
) ENGINE = InnoDB;


-- 5. CLIENTS
-- BR-09: Client details; phone and email are unique.
-- BR-10: Reservation history will be obtained by query.

CREATE TABLE clients (
    client_id INT UNSIGNED AUTO_INCREMENT,
    last_name VARCHAR(80) NOT NULL,
    first_name VARCHAR(80) NOT NULL,
    phone VARCHAR(25) NOT NULL,
    email VARCHAR(254) NOT NULL,

    CONSTRAINT pk_clients
        PRIMARY KEY (client_id),

    CONSTRAINT uq_clients_phone
        UNIQUE (phone),

    CONSTRAINT uq_clients_email
        UNIQUE (email)
) ENGINE = InnoDB;


-- 6. RESERVATIONS
-- BR-04: Each reservation belongs to one client.
-- BR-05: Checkout must be later than check-in.
-- BR-06: Track status and creation/cancellation dates.

CREATE TABLE reservations (
    reservation_id INT UNSIGNED AUTO_INCREMENT,
    client_id INT UNSIGNED NOT NULL,
    check_in_date DATE NOT NULL,
    check_out_date DATE NOT NULL,
    guest_count SMALLINT UNSIGNED NOT NULL,
    reservation_status ENUM(
        'pending',
        'confirmed',
        'cancelled',
        'completed'
    ) NOT NULL DEFAULT 'pending',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    cancelled_at DATETIME NULL,

    CONSTRAINT pk_reservations
        PRIMARY KEY (reservation_id),

    CONSTRAINT chk_reservation_dates
        CHECK (check_out_date > check_in_date),

    CONSTRAINT chk_reservation_guests
        CHECK (guest_count > 0),

    CONSTRAINT chk_reservation_cancellation
        CHECK (
            (reservation_status = 'cancelled'
                AND cancelled_at IS NOT NULL)
            OR
            (reservation_status <> 'cancelled'
                AND cancelled_at IS NULL)
        ),

    CONSTRAINT fk_reservations_client
        FOREIGN KEY (client_id)
        REFERENCES clients(client_id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE
) ENGINE = InnoDB;


-- Verify the tables created so far.

SHOW TABLES;


-- =====================================================
-- CONTINUATION OF 01_schema.sql
-- Remaining Hotel Management Database tables
-- =====================================================

USE hotel_management;


-- 7. RESERVATION_ROOMS
-- BR-04: A reservation can include multiple rooms.
-- BR-07: Room overlap validation will be added later.
-- BR-08: Preserve the nightly price agreed at booking.

CREATE TABLE reservation_rooms (
    reservation_id INT UNSIGNED NOT NULL,
    room_id INT UNSIGNED NOT NULL,
    booked_price_per_night DECIMAL(10,2) NOT NULL,

    CONSTRAINT pk_reservation_rooms
        PRIMARY KEY (reservation_id, room_id),

    CONSTRAINT chk_booked_room_price
        CHECK (booked_price_per_night >= 0),

    CONSTRAINT fk_rr_reservation
        FOREIGN KEY (reservation_id)
        REFERENCES reservations(reservation_id)
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    CONSTRAINT fk_rr_room
        FOREIGN KEY (room_id)
        REFERENCES rooms(room_id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE
) ENGINE = InnoDB;


-- 8. SERVICES
-- BR-11: Define hotel services and slot capacity.

CREATE TABLE services (
    service_id INT UNSIGNED AUTO_INCREMENT,
    service_name VARCHAR(100) NOT NULL,
    description VARCHAR(500) NOT NULL,
    price DECIMAL(10,2) NOT NULL,
    slot_capacity SMALLINT UNSIGNED NOT NULL,

    CONSTRAINT pk_services
        PRIMARY KEY (service_id),

    CONSTRAINT uq_services_name
        UNIQUE (service_name),

    CONSTRAINT chk_service_price
        CHECK (price >= 0),

    CONSTRAINT chk_service_capacity
        CHECK (slot_capacity > 0)
) ENGINE = InnoDB;


-- 9. SERVICE_OPENING_HOURS
-- BR-11: Opening hours for each weekday.
-- Monday = 1; Sunday = 7.

CREATE TABLE service_opening_hours (
    service_id INT UNSIGNED NOT NULL,
    day_of_week TINYINT UNSIGNED NOT NULL,
    opens_at TIME NOT NULL,
    closes_at TIME NOT NULL,

    CONSTRAINT pk_service_opening_hours
        PRIMARY KEY (service_id, day_of_week),

    CONSTRAINT chk_opening_day
        CHECK (day_of_week BETWEEN 1 AND 7),

    CONSTRAINT chk_opening_times
        CHECK (closes_at > opens_at),

    CONSTRAINT fk_soh_service
        FOREIGN KEY (service_id)
        REFERENCES services(service_id)
        ON DELETE CASCADE
        ON UPDATE CASCADE
) ENGINE = InnoDB;


-- 10. SERVICE_BOOKINGS
-- BR-12: Book a service during a guest's stay.
-- Capacity, opening hours and stay dates require
-- additional validation in the constraints stage.

CREATE TABLE service_bookings (
    service_booking_id INT UNSIGNED AUTO_INCREMENT,
    reservation_id INT UNSIGNED NOT NULL,
    service_id INT UNSIGNED NOT NULL,
    slot_start DATETIME NOT NULL,
    slot_end DATETIME NOT NULL,
    quantity SMALLINT UNSIGNED NOT NULL DEFAULT 1,
    booked_unit_price DECIMAL(10,2) NOT NULL,

    CONSTRAINT pk_service_bookings
        PRIMARY KEY (service_booking_id),

    CONSTRAINT chk_service_slot
        CHECK (slot_end > slot_start),

    CONSTRAINT chk_service_quantity
        CHECK (quantity > 0),

    CONSTRAINT chk_booked_service_price
        CHECK (booked_unit_price >= 0),

    CONSTRAINT fk_sb_reservation
        FOREIGN KEY (reservation_id)
        REFERENCES reservations(reservation_id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,

    CONSTRAINT fk_sb_service
        FOREIGN KEY (service_id)
        REFERENCES services(service_id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE
) ENGINE = InnoDB;


-- 11. INVOICES
-- BR-13: At most one invoice per reservation.
-- BR-15: Payment status is maintained later.

CREATE TABLE invoices (
    invoice_id INT UNSIGNED AUTO_INCREMENT,
    reservation_id INT UNSIGNED NOT NULL,
    issued_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    status ENUM(
        'due',
        'partially_paid',
        'paid'
    ) NOT NULL DEFAULT 'due',

    CONSTRAINT pk_invoices
        PRIMARY KEY (invoice_id),

    CONSTRAINT uq_invoice_reservation
        UNIQUE (reservation_id),

    CONSTRAINT fk_invoice_reservation
        FOREIGN KEY (reservation_id)
        REFERENCES reservations(reservation_id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE
) ENGINE = InnoDB;


-- 12. INVOICE_LINES
-- BR-13: Itemized accommodation and service charges.
-- Prices and tax rates are preserved at invoicing time.

CREATE TABLE invoice_lines (
    invoice_line_id INT UNSIGNED AUTO_INCREMENT,
    invoice_id INT UNSIGNED NOT NULL,
    line_type ENUM(
        'accommodation',
        'service',
        'miscellaneous'
    ) NOT NULL,
    description VARCHAR(255) NOT NULL,
    quantity DECIMAL(10,2) NOT NULL,
    unit_price DECIMAL(10,2) NOT NULL,
    tax_rate DECIMAL(5,2) NOT NULL DEFAULT 0,

    CONSTRAINT pk_invoice_lines
        PRIMARY KEY (invoice_line_id),

    CONSTRAINT chk_invoice_line_quantity
        CHECK (quantity > 0),

    CONSTRAINT chk_invoice_line_price
        CHECK (unit_price >= 0),

    CONSTRAINT chk_invoice_line_tax
        CHECK (tax_rate BETWEEN 0 AND 100),

    CONSTRAINT fk_line_invoice
        FOREIGN KEY (invoice_id)
        REFERENCES invoices(invoice_id)
        ON DELETE CASCADE
        ON UPDATE CASCADE
) ENGINE = InnoDB;


-- 13. PAYMENTS
-- BR-14: Multiple payments may be made toward an invoice.
-- BR-15: Payment procedure will update invoice status.

CREATE TABLE payments (
    payment_id INT UNSIGNED AUTO_INCREMENT,
    invoice_id INT UNSIGNED NOT NULL,
    payment_date DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    amount DECIMAL(10,2) NOT NULL,
    method ENUM(
        'cash',
        'card',
        'mobile_money',
        'bank_transfer'
    ) NOT NULL,

    CONSTRAINT pk_payments
        PRIMARY KEY (payment_id),

    CONSTRAINT chk_payment_amount
        CHECK (amount > 0),

    CONSTRAINT fk_payment_invoice
        FOREIGN KEY (invoice_id)
        REFERENCES invoices(invoice_id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE
) ENGINE = InnoDB;


-- 14. REVIEWS
-- BR-16: At most one review per reservation.
-- BR-17: Ratings must be between 1 and 5.
-- Completed-stay validation will be added later.

CREATE TABLE reviews (
    review_id INT UNSIGNED AUTO_INCREMENT,
    reservation_id INT UNSIGNED NOT NULL,
    rating TINYINT UNSIGNED NOT NULL,
    comment VARCHAR(1000) NULL,
    review_date DATE NOT NULL,

    CONSTRAINT pk_reviews
        PRIMARY KEY (review_id),

    CONSTRAINT uq_review_reservation
        UNIQUE (reservation_id),

    CONSTRAINT chk_review_rating
        CHECK (rating BETWEEN 1 AND 5),

    CONSTRAINT fk_review_reservation
        FOREIGN KEY (reservation_id)
        REFERENCES reservations(reservation_id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE
) ENGINE = InnoDB;


-- =====================================================
-- VERIFY ALL TABLES
-- =====================================================

SHOW TABLES;