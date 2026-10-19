# Data Dictionary

This dictionary describes the tables declared in [`sql/01_schema.sql`](../sql/01_schema.sql). MySQL types and constraints in that script are authoritative. The ERD image is a visual reference and may not show every column or rule.

| Table | Purpose | Key relationships |
| --- | --- | --- |
| `room_types` | Room category names. | Referenced by `rooms`. |
| `rooms` | Physical rooms, capacity, type, price, and operational status. | Belongs to `room_types`; connects to `amenities` through `room_amenities`; connects to reservations through `reservation_rooms`. |
| `amenities` | Reusable amenity names. | Connects to `rooms` through `room_amenities`. |
| `room_amenities` | Room-to-amenity many-to-many links. | References `rooms` and `amenities`. |
| `clients` | Guest contact details. | One client can have many `reservations`. |
| `reservations` | Guest stay dates, guest count, status, and timestamps. | Belongs to `clients`; connects to `rooms` through `reservation_rooms`; referenced by service bookings, invoices, and reviews. |
| `reservation_rooms` | Rooms assigned to a reservation and the booked nightly price. | References `reservations` and `rooms`. |
| `services` | Hotel services, descriptions, prices, and slot capacity. | Has opening-hour rows and service bookings. |
| `service_opening_hours` | Opening and closing times by service and weekday. | References `services`. Monday is 1 and Sunday is 7. |
| `service_bookings` | Service slots booked for a reservation, including quantity and booked price. | References `reservations` and `services`. |
| `invoices` | One invoice per reservation, with issue time and payment status. | References `reservations`; has `invoice_lines` and `payments`. |
| `invoice_lines` | Itemized accommodation, service, or miscellaneous charges and tax. | References `invoices`. |
| `payments` | Payments applied to invoices. | References `invoices`; multiple payments may belong to one invoice. |
| `reviews` | A reservation's rating, comment, and review date. | References `reservations`; at most one review per reservation. |

## Important Rules

- Reservation checkout must be later than check-in, and guest count must be positive.
- A cancelled reservation must have `cancelled_at` set; other statuses require it to be `NULL`.
- Room type names, room numbers, amenity names, service names, client phone numbers, and client email addresses are unique.
- A reservation can include multiple rooms, and the booked nightly room price is preserved in `reservation_rooms`.
- Invoice line quantity must be positive; unit price must be nonnegative; tax rate is between 0 and 100.
- Payment amounts must be positive. Reviews are unique per reservation and ratings are from 1 through 5.
- The schema uses foreign keys and checks, while `sql/02_constraints.sql` adds triggers and procedures for active room overlaps, room capacity on confirmation, service stay/opening-hour/slot-capacity rules, completed-stay reviews, invoice payment limits, and invoice status maintenance.