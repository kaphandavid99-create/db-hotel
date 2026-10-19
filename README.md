# Hotel Database

MySQL 8 database schema for a hotel reservation and services system. The repository also contains a Next.js interface in `web/` and a staging copy in `hotel-db-next-staging/`.

## Repository Layout

```text
hotel-db/
|-- README.md
|-- docs/
|   |-- erd.png
|   `-- data_dictionary.md
|-- sql/
|   |-- 01_schema.sql
|   |-- 02_constraints.sql
|   |-- 02_seed_data.sql
|   |-- 03_seed_data_tests.sql
|   |-- 05_tests.sql
|   |-- 06_analytics.sql
|   |-- 07_analytics_test_fixture.sql
|   |-- ANALYTICS.md
|   `-- SEED_DATA.md
|-- web/
`-- hotel-db-next-staging/
```

## Database Setup

Run SQL scripts in MySQL 8 in this order:

```sh
mysql -u YOUR_USER -p < sql/01_schema.sql
mysql -u YOUR_USER -p hotel_management < sql/02_constraints.sql
mysql -u YOUR_USER -p hotel_management < sql/05_tests.sql
```

The schema creates the `hotel_management` database and its 14 tables. The constraints script installs the business-rule triggers and procedures; the tests report `passed = 1` for each expected failure or payment-status assertion.

Run `sql/05_tests.sql` after the schema and constraints to exercise expected constraint failures and payment status updates. The test fixtures are rolled back. For non-production sample data, run `sql/02_seed_data.sql` after the schema and constraints, then `sql/03_seed_data_tests.sql` to check the seed. See [sql/SEED_DATA.md](sql/SEED_DATA.md) for details and safety notes.

The reporting queries are in `sql/06_analytics.sql` (the current equivalent of the pictured `04_queries.sql`); run them with the session variables described in [sql/ANALYTICS.md](sql/ANALYTICS.md). The optional `sql/07_analytics_test_fixture.sql` supplies temporary sample tables for exercising those reports.

The ERD reference is [docs/erd.png](docs/erd.png), and [docs/data_dictionary.md](docs/data_dictionary.md) describes the schema tables.

## Web Applications

The `web/` and `hotel-db-next-staging/` directories are separate Next.js projects. Each has its own `package.json` and README. The web interface is not currently connected to the SQL database.