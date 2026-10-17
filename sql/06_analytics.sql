USE hotel_management;

-- Parameter contract (set these session variables before running the relevant query):
-- SET @room_type_name = 'Standard';
-- SET @check_in_date = '2026-06-01';
-- SET @check_out_date = '2026-06-04';
-- SET @report_start = '2026-06-01';
-- SET @report_end = '2026-08-01'; -- exclusive
-- Session variables keep values separate from SQL text and work in MySQL Workbench/CLI.

-- 1. Available rooms by type and half-open stay interval [check-in, check-out).
-- Confirmed/completed reservations block rooms; pending requests do not hold inventory.
-- The current operational status is not historical availability; only currently
-- out-of-service rooms are excluded. Occupied/being-cleaned statuses are date-agnostic.
SELECT
    room.room_id,
    room.room_number,
    room.floor_number,
    room_type.type_name,
    room.max_capacity,
    room.base_price_per_night,
    room.operational_status
FROM rooms AS room
INNER JOIN room_types AS room_type
    ON room_type.room_type_id = room.room_type_id
WHERE room_type.type_name = @room_type_name
  AND @check_in_date IS NOT NULL
  AND @check_out_date IS NOT NULL
  AND @check_in_date < @check_out_date
  AND room.operational_status <> 'out_of_service'
  AND NOT EXISTS (
      SELECT 1
      FROM reservation_rooms AS reserved_room
      INNER JOIN reservations AS reservation
          ON reservation.reservation_id = reserved_room.reservation_id
      WHERE reserved_room.room_id = room.room_id
        AND reservation.reservation_status IN ('confirmed', 'completed')
        AND reservation.check_in_date < @check_out_date
        AND reservation.check_out_date > @check_in_date
  )
ORDER BY room.floor_number, room.room_number;


-- 2. Monthly occupancy for [@report_start, @report_end).
-- Inventory has no effective dates or historical maintenance records, so every
-- room currently stored contributes one available night per date in the range.
-- Pending/cancelled reservations are not nights sold; checked-out stays are.
-- Overlapping reservation rows are unioned per room/month before summing.
WITH RECURSIVE
report_parameters AS (
    SELECT
        CAST(@report_start AS DATE) AS report_start,
        CAST(@report_end AS DATE) AS report_end,
        CAST(DATE_FORMAT(DATE_SUB(CAST(@report_end AS DATE), INTERVAL 1 DAY), '%Y-%m-01') AS DATE) AS last_month
    WHERE @report_start IS NOT NULL
      AND @report_end IS NOT NULL
      AND CAST(@report_start AS DATE) < CAST(@report_end AS DATE)
),
report_months AS (
    SELECT
        CAST(DATE_FORMAT(report_start, '%Y-%m-01') AS DATE) AS month_start,
        report_start,
        report_end,
        last_month
    FROM report_parameters
    UNION ALL
    SELECT
        DATE_ADD(month_start, INTERVAL 1 MONTH),
        report_start,
        report_end,
        last_month
    FROM report_months
    WHERE month_start < last_month
),
room_inventory AS (
    SELECT COUNT(*) AS room_count
    FROM rooms
),
room_stay_intervals AS (
    SELECT
        month.month_start,
        room.room_id,
        reservation.reservation_id,
        GREATEST(reservation.check_in_date, month.month_start, month.report_start) AS stay_start,
        LEAST(reservation.check_out_date, DATE_ADD(month.month_start, INTERVAL 1 MONTH), month.report_end) AS stay_end
    FROM report_months AS month
    INNER JOIN reservations AS reservation
        ON reservation.reservation_status IN ('confirmed', 'completed')
       AND reservation.check_in_date < LEAST(DATE_ADD(month.month_start, INTERVAL 1 MONTH), month.report_end)
       AND reservation.check_out_date > GREATEST(month.month_start, month.report_start)
    INNER JOIN reservation_rooms AS reserved_room
        ON reserved_room.reservation_id = reservation.reservation_id
    INNER JOIN rooms AS room
        ON room.room_id = reserved_room.room_id
),
ordered_room_stays AS (
    SELECT
        room_stay.*,
        MAX(room_stay.stay_end) OVER (
            PARTITION BY room_stay.month_start, room_stay.room_id
            ORDER BY room_stay.stay_start, room_stay.stay_end, room_stay.reservation_id
            ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
        ) AS previously_covered_until
    FROM room_stay_intervals AS room_stay
),
monthly_sold_totals AS (
    SELECT
        month_start,
        SUM(
            GREATEST(
                DATEDIFF(stay_end, GREATEST(stay_start, COALESCE(previously_covered_until, stay_start))),
                0
            )
        ) AS nights_sold
    FROM ordered_room_stays
    GROUP BY month_start
)
SELECT
    DATE_FORMAT(month.month_start, '%Y-%m') AS reporting_month,
    COALESCE(sold.nights_sold, 0) AS nights_sold,
    inventory.room_count * DATEDIFF(
        LEAST(DATE_ADD(month.month_start, INTERVAL 1 MONTH), month.report_end),
        GREATEST(month.month_start, month.report_start)
    ) AS nights_available,
    ROUND(
        CASE
            WHEN inventory.room_count = 0 THEN 0
            ELSE COALESCE(sold.nights_sold, 0) * 100.0 /
                 NULLIF(
                     inventory.room_count * DATEDIFF(
                         LEAST(DATE_ADD(month.month_start, INTERVAL 1 MONTH), month.report_end),
                         GREATEST(month.month_start, month.report_start)
                     ),
                     0
                 )
        END,
        2
    ) AS occupancy_rate_percent
FROM report_months AS month
CROSS JOIN room_inventory AS inventory
LEFT JOIN monthly_sold_totals AS sold
    ON sold.month_start = month.month_start
ORDER BY month.month_start;


-- 3. Monthly paid revenue by payment_date, prorated across itemized invoice lines.
-- Applied payments are capped at the invoice's gross line total to avoid treating
-- overpayments as revenue. Partial payments inherit the invoice's line mix. Tax is
-- included; miscellaneous lines are exposed separately so total reconciles exactly.
-- Cancelled reservations are excluded. The schema has no refunds/reversals to net.
WITH RECURSIVE
report_parameters AS (
    SELECT
        CAST(@report_start AS DATE) AS report_start,
        CAST(@report_end AS DATE) AS report_end,
        CAST(DATE_FORMAT(DATE_SUB(CAST(@report_end AS DATE), INTERVAL 1 DAY), '%Y-%m-01') AS DATE) AS last_month
    WHERE @report_start IS NOT NULL
      AND @report_end IS NOT NULL
      AND CAST(@report_start AS DATE) < CAST(@report_end AS DATE)
),
report_months AS (
    SELECT
        CAST(DATE_FORMAT(report_start, '%Y-%m-01') AS DATE) AS month_start,
        report_start,
        report_end,
        last_month
    FROM report_parameters
    UNION ALL
    SELECT DATE_ADD(month_start, INTERVAL 1 MONTH), report_start, report_end, last_month
    FROM report_months
    WHERE month_start < last_month
),
invoice_line_totals AS (
    SELECT
        line.invoice_id,
        SUM(line.quantity * line.unit_price * (1 + line.tax_rate / 100)) AS invoice_total,
        SUM(CASE WHEN line.line_type = 'accommodation' THEN line.quantity * line.unit_price * (1 + line.tax_rate / 100) ELSE 0 END) AS accommodation_total,
        SUM(CASE WHEN line.line_type = 'service' THEN line.quantity * line.unit_price * (1 + line.tax_rate / 100) ELSE 0 END) AS services_total,
        SUM(CASE WHEN line.line_type = 'miscellaneous' THEN line.quantity * line.unit_price * (1 + line.tax_rate / 100) ELSE 0 END) AS miscellaneous_total
    FROM invoice_lines AS line
    GROUP BY line.invoice_id
),
payment_running_totals AS (
    SELECT
        payment.payment_id,
        payment.invoice_id,
        payment.payment_date,
        payment.amount,
        line_total.invoice_total,
        line_total.accommodation_total,
        line_total.services_total,
        line_total.miscellaneous_total,
        SUM(payment.amount) OVER (
            PARTITION BY payment.invoice_id
            ORDER BY payment.payment_date, payment.payment_id
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS cumulative_paid
    FROM payments AS payment
    INNER JOIN invoices AS invoice
        ON invoice.invoice_id = payment.invoice_id
    INNER JOIN reservations AS reservation
        ON reservation.reservation_id = invoice.reservation_id
       AND reservation.reservation_status <> 'cancelled'
    INNER JOIN invoice_line_totals AS line_total
        ON line_total.invoice_id = payment.invoice_id
),
applied_payments AS (
    SELECT
        payment_date,
        invoice_total,
        accommodation_total,
        services_total,
        miscellaneous_total,
        LEAST(amount, GREATEST(invoice_total - (cumulative_paid - amount), 0)) AS applied_amount
    FROM payment_running_totals
),
monthly_revenue AS (
    SELECT
        CAST(DATE_FORMAT(payment.payment_date, '%Y-%m-01') AS DATE) AS month_start,
        SUM(payment.applied_amount * payment.accommodation_total / NULLIF(payment.invoice_total, 0)) AS accommodation_revenue,
        SUM(payment.applied_amount * payment.services_total / NULLIF(payment.invoice_total, 0)) AS services_revenue,
        SUM(payment.applied_amount * payment.miscellaneous_total / NULLIF(payment.invoice_total, 0)) AS miscellaneous_revenue
    FROM applied_payments AS payment
    CROSS JOIN report_parameters AS parameters
    WHERE payment.payment_date >= parameters.report_start
      AND payment.payment_date < parameters.report_end
    GROUP BY CAST(DATE_FORMAT(payment.payment_date, '%Y-%m-01') AS DATE)
)
SELECT
    DATE_FORMAT(month.month_start, '%Y-%m') AS reporting_month,
    ROUND(COALESCE(revenue.accommodation_revenue, 0), 2) AS accommodation_revenue,
    ROUND(COALESCE(revenue.services_revenue, 0), 2) AS services_revenue,
    ROUND(COALESCE(revenue.miscellaneous_revenue, 0), 2) AS miscellaneous_revenue,
    ROUND(
        COALESCE(revenue.accommodation_revenue, 0)
        + COALESCE(revenue.services_revenue, 0)
        + COALESCE(revenue.miscellaneous_revenue, 0),
        2
    ) AS total_revenue
FROM report_months AS month
LEFT JOIN monthly_revenue AS revenue
    ON revenue.month_start = month.month_start
ORDER BY month.month_start;


-- 4. Unpaid/partially-paid invoices with positive outstanding balances.
-- Invoice totals include tax; all payment rows are aggregated before joining so
-- payments and invoice lines cannot multiply each other. No refund adjustment exists.
WITH invoice_line_totals AS (
    SELECT
        line.invoice_id,
        SUM(line.quantity * line.unit_price * (1 + line.tax_rate / 100)) AS invoice_total
    FROM invoice_lines AS line
    GROUP BY line.invoice_id
),
payment_totals AS (
    SELECT payment.invoice_id, SUM(payment.amount) AS amount_paid
    FROM payments AS payment
    GROUP BY payment.invoice_id
),
invoice_balances AS (
    SELECT
        invoice.invoice_id,
        invoice.issued_at,
        invoice.status AS invoice_status,
        reservation.reservation_status,
        client.client_id,
        client.first_name,
        client.last_name,
        client.email,
        client.phone,
        COALESCE(line_total.invoice_total, 0) AS total_amount,
        COALESCE(payment_total.amount_paid, 0) AS amount_paid,
        GREATEST(COALESCE(line_total.invoice_total, 0) - COALESCE(payment_total.amount_paid, 0), 0) AS outstanding_balance
    FROM invoices AS invoice
    INNER JOIN reservations AS reservation
        ON reservation.reservation_id = invoice.reservation_id
       AND reservation.reservation_status <> 'cancelled'
    INNER JOIN clients AS client
        ON client.client_id = reservation.client_id
    LEFT JOIN invoice_line_totals AS line_total
        ON line_total.invoice_id = invoice.invoice_id
    LEFT JOIN payment_totals AS payment_total
        ON payment_total.invoice_id = invoice.invoice_id
)
SELECT
    invoice_id,
    client_id,
    first_name,
    last_name,
    email,
    phone,
    issued_at AS invoice_date,
    invoice_status,
    total_amount,
    amount_paid,
    outstanding_balance
FROM invoice_balances
WHERE outstanding_balance > 0
ORDER BY invoice_date ASC, invoice_id ASC;


-- 5. Average reviews per room type. The distinct review/type CTE ensures a
-- multi-room reservation cannot inflate a room type's review count or average.
WITH review_room_types AS (
    SELECT DISTINCT
        review.review_id,
        room_type.room_type_id,
        review.rating
    FROM reviews AS review
    INNER JOIN reservation_rooms AS reserved_room
        ON reserved_room.reservation_id = review.reservation_id
    INNER JOIN rooms AS room
        ON room.room_id = reserved_room.room_id
    INNER JOIN room_types AS room_type
        ON room_type.room_type_id = room.room_type_id
)
SELECT
    room_type.room_type_id,
    room_type.type_name AS room_type,
    ROUND(AVG(review_room_type.rating), 2) AS average_rating,
    COUNT(review_room_type.review_id) AS review_count
FROM room_types AS room_type
LEFT JOIN review_room_types AS review_room_type
    ON review_room_type.room_type_id = room_type.room_type_id
GROUP BY room_type.room_type_id, room_type.type_name
ORDER BY room_type.type_name;


-- 6. Top five clients by actual paid amounts on non-cancelled reservations.
-- Payment totals are capped to invoiced gross totals; pending reservations may
-- have payments, but only confirmed/completed reservations count as stays.
-- Positive-only payments are the schema's only payment representation.
WITH invoice_line_totals AS (
    SELECT
        line.invoice_id,
        SUM(line.quantity * line.unit_price * (1 + line.tax_rate / 100)) AS invoice_total
    FROM invoice_lines AS line
    GROUP BY line.invoice_id
),
payment_running_totals AS (
    SELECT
        payment.payment_id,
        payment.invoice_id,
        payment.amount,
        line_total.invoice_total,
        SUM(payment.amount) OVER (
            PARTITION BY payment.invoice_id
            ORDER BY payment.payment_date, payment.payment_id
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS cumulative_paid
    FROM payments AS payment
    INNER JOIN invoices AS invoice
        ON invoice.invoice_id = payment.invoice_id
    INNER JOIN reservations AS reservation
        ON reservation.reservation_id = invoice.reservation_id
       AND reservation.reservation_status <> 'cancelled'
    INNER JOIN invoice_line_totals AS line_total
        ON line_total.invoice_id = payment.invoice_id
),
client_spending AS (
    SELECT
        reservation.client_id,
        SUM(LEAST(payment.amount, GREATEST(payment.invoice_total - (payment.cumulative_paid - payment.amount), 0))) AS total_spending
    FROM payment_running_totals AS payment
    INNER JOIN invoices AS invoice
        ON invoice.invoice_id = payment.invoice_id
    INNER JOIN reservations AS reservation
        ON reservation.reservation_id = invoice.reservation_id
       AND reservation.reservation_status <> 'cancelled'
    GROUP BY reservation.client_id
),
client_stays AS (
    SELECT
        reservation.client_id,
        COUNT(DISTINCT reservation.reservation_id) AS stay_count
    FROM reservations AS reservation
    WHERE reservation.reservation_status IN ('confirmed', 'completed')
    GROUP BY reservation.client_id
)
SELECT
    client.client_id,
    client.first_name,
    client.last_name,
    ROUND(spending.total_spending, 2) AS total_spending,
    COALESCE(stays.stay_count, 0) AS stay_count
FROM client_spending AS spending
INNER JOIN clients AS client
    ON client.client_id = spending.client_id
LEFT JOIN client_stays AS stays
    ON stays.client_id = spending.client_id
WHERE spending.total_spending > 0
ORDER BY spending.total_spending DESC, client.client_id ASC
LIMIT 5;