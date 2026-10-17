# Hotel Analytics Queries

`06_analytics.sql` contains six MySQL 8 queries against the current schema. It adds
no tables and uses MySQL session variables for input values. Run it in the same
connection in which the variables are set.

## Run

1. Create the database by running `01_schema.sql` if it does not exist.
2. Set the query parameters in MySQL Workbench or the MySQL CLI:

```sql
SET @room_type_name = 'Standard';
SET @check_in_date = '2026-06-02';
SET @check_out_date = '2026-06-04';
SET @report_start = '2026-06-01';
SET @report_end = '2026-08-01'; -- exclusive
```

3. Run `06_analytics.sql`. It returns results for room availability, monthly
   occupancy, monthly paid revenue, unpaid invoices, room-type reviews, and top
   spending clients, in that order.

To run the sample checks, first create the schema, then execute
`07_analytics_test_fixture.sql` and `06_analytics.sql` in the same connection.
The fixture uses temporary tables that shadow the real tables for that session;
it does not insert into or delete persistent application records. Expected values
and the zero-room edge-case command are included at the end of the fixture.

## Rules And Limitations

- Room intervals are half-open: `[check-in, check-out)`. Existing reservations
  with status `confirmed` or `completed` block an overlapping room. `pending`
  reservations do not hold inventory. `cancelled` reservations do not block.
- Occupancy counts booked room-nights for `confirmed` and `completed`
  reservations. Available nights use the room inventory currently in `rooms`;
  the schema has no room-inventory effective dates or historical maintenance
  periods, so historical monthly inventory cannot be reconstructed exactly.
- Monthly revenue is grouped by `payments.payment_date`, not invoice issue date.
  Each payment is capped against its invoice's itemized gross total, and partial
  payments are allocated proportionally across invoice line types. Tax is included.
  `miscellaneous_revenue` is returned so total revenue reconciles when an invoice
  includes miscellaneous lines.
- The schema has no refund, reversal, credit-note, or adjustment table, and
  `payments.amount` must be positive. Therefore refunds cannot be netted or
  identified. Reports use the positive payment rows present and exclude cancelled
  reservations where noted.
- Invoice balances are calculated from `invoice_lines` (including tax) minus
  payment rows. Any positive balance is returned, even if the invoice status enum
  is stale; the stored enum is included for inspection. Cancelled reservations
  are excluded because the schema has no separate invoice-cancellation state.
- A review is associated with the room type(s) booked on its reservation. A
  review for a multi-room reservation is counted once per distinct room type,
  while never multiplying within the same type.
- Qualifying client spending is capped paid value on non-cancelled reservations.
  Stay count includes only `confirmed` and `completed` reservation records.

The web app currently has no API/backend or database driver configured, so the
queries are delivered as executable SQL rather than wired to demo dashboard data.