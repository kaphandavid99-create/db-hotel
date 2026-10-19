# Hotel Management Seed Data

The schema is MySQL 8/InnoDB. The project has no ORM, database driver, or
existing database seed convention, so the seed is implemented in SQL using the
tables already declared in `01_schema.sql`.

## Run

Run against a development/test database, never a production database. Create the
schema and install the business-rule triggers first, then seed and verify:

```sh
mysql -u YOUR_USER -p < sql/01_schema.sql
mysql -u YOUR_USER -p hotel_management < sql/02_constraints.sql
mysql -u YOUR_USER -p hotel_management < sql/02_seed_data.sql
mysql -u YOUR_USER -p hotel_management < sql/03_seed_data_tests.sql
```

The seed wraps persistent inserts in a transaction, only inserts rows that are
missing by their natural keys/signatures, does not update or delete existing
rows, and uses `.invalid` email addresses plus `Seed`-prefixed service names to
keep sample records identifiable. It seeds 12 clients, 12 rooms, 20
reservations, four services with weekday/weekend opening hours (and a spa closed
Sunday), six service bookings, ten invoices, payments, and eight reviews. Client
11 and client 12 intentionally have no reservations. Reservation 20 uses both
Harbor Suite rooms through `reservation_rooms`.

New reservations are staged as `pending`. After room links are added, the seed
activates only newly created reservations with sufficient room capacity and no
conflicting active stay. Existing reservation statuses remain unchanged.

Before adding a reservation-room link, the script checks that the room type
matches the seed catalog and that no confirmed/completed stay already overlaps
the dates. A conflicting link is skipped rather than overbooking or changing an
existing reservation; the verification script then reports incomplete seed
relationships so the room-number collision can be resolved deliberately.

The first seeded reservation anchors the dates. Rerunning the script reuses that
anchor instead of shifting all sample dates, and checks the existing rows before
inserting. It is designed for a development database; collisions with preexisting
rows under the reserved seed keys are left untouched and reported by the tests.

## Verification

`03_seed_data_tests.sql` returns one row per requirement with `passed = 1` for
success. It checks client/reservation/service/invoice/review counts, the
unreserved client, required reservation statuses, the multi-room relationship,
absence of overlapping confirmed/completed seed room assignments, service-hour
variation and closure, all three invoice payment states, and rating coverage
from 1 through 5.

The current schema has no review-to-client or review-to-room foreign key: reviews
belong to reservations, and the client/room association is derived through
`reservations` and `reservation_rooms`. The seed follows that existing design and
does not add schema objects.