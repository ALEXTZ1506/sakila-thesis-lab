-- =============================================================================
-- SCRIPT: Insert Data Inflation (PostgreSQL)
-- OBJECTIVE: Multiply data volume to reach ~500k+ rows for stress testing.
--
-- This file is the PostgreSQL mirror of mysql-sakila-insert-data-inflation.sql.
-- It exists to keep MariaDB and PostgreSQL baselines volumetrically symmetric
-- so the thesis-level claim of "schematic and volumetric equivalence" holds
-- after inflation. Both scripts apply the same 5 self-doubling INSERT...SELECT
-- iterations to `rental` and `payment`, raising each from ~16K to ~513K rows
-- (factor 2^5 = 32x). No other tables are touched.
--
-- DESIGN DECISION (documented limitation, intentional):
--   Inflated `payment` rows carry rental_id = NULL exactly as in the MySQL
--   counterpart. Re-associating each inflated payment to its source rental
--   would require per-row RETURNING bookkeeping that the MySQL script does
--   not perform, so leaving NULL keeps both backends symmetric. The FK
--   payment_rental_id_fkey is ON UPDATE CASCADE ON DELETE SET NULL on a
--   nullable column, so this insertion is legal.
--
--   Consequence: analytic queries that join payment -> rental -> inventory
--   -> film will only see the original ~16K payments (1/32 of the
--   post-inflation total). This is acceptable for the thesis because the
--   audit-overhead measurements operate on row volume written and audited,
--   not on JOIN-graph completeness.
--
-- IDEMPOTENCY GUARD:
--   The script is NOT idempotent: a second run would violate
--   idx_unq_rental_rental_date_inventory_id_customer_id (same date+inv+cust
--   already exists from the previous inflation). The guard below aborts
--   cleanly if `rental` already exceeds the Sakila baseline, instead of
--   failing midway through with a confusing unique-violation error.
--   To re-run, reload the base dataset first (drop-objects + schema +
--   insert-data-using-copy), then run this script again.
-- =============================================================================

-- ---------------------------------------------------------
-- GUARD: refuse to run if data has already been inflated
-- ---------------------------------------------------------
DO $$
DECLARE
    v_rental_count BIGINT;
BEGIN
    SELECT COUNT(*) INTO v_rental_count FROM rental;
    IF v_rental_count > 20000 THEN
        RAISE EXCEPTION
            'Inflation appears to have run already (rental rows = %, baseline ~16044). Reload the base dataset before running this script again.',
            v_rental_count;
    END IF;
END$$;

-- ---------------------------------------------------------
-- STEP 1: Inflate RENTAL table
-- ---------------------------------------------------------

DO $$ BEGIN RAISE NOTICE 'Inflating RENTAL table...'; END$$;

INSERT INTO rental (rental_date, inventory_id, customer_id, return_date, staff_id, last_update)
SELECT rental_date + INTERVAL '1 year', inventory_id, customer_id, return_date + INTERVAL '1 year', staff_id, CURRENT_TIMESTAMP
FROM rental;

INSERT INTO rental (rental_date, inventory_id, customer_id, return_date, staff_id, last_update)
SELECT rental_date + INTERVAL '2 year', inventory_id, customer_id, return_date + INTERVAL '2 year', staff_id, CURRENT_TIMESTAMP
FROM rental;

INSERT INTO rental (rental_date, inventory_id, customer_id, return_date, staff_id, last_update)
SELECT rental_date + INTERVAL '3 year', inventory_id, customer_id, return_date + INTERVAL '3 year', staff_id, CURRENT_TIMESTAMP
FROM rental;

INSERT INTO rental (rental_date, inventory_id, customer_id, return_date, staff_id, last_update)
SELECT rental_date + INTERVAL '4 year', inventory_id, customer_id, return_date + INTERVAL '4 year', staff_id, CURRENT_TIMESTAMP
FROM rental;

INSERT INTO rental (rental_date, inventory_id, customer_id, return_date, staff_id, last_update)
SELECT rental_date + INTERVAL '5 year', inventory_id, customer_id, return_date + INTERVAL '5 year', staff_id, CURRENT_TIMESTAMP
FROM rental;

-- ---------------------------------------------------------
-- STEP 2: Inflate PAYMENT table
--   NOTE: rental_id is set to NULL on inflated rows by design (see header).
-- ---------------------------------------------------------

DO $$ BEGIN RAISE NOTICE 'Inflating PAYMENT table...'; END$$;

INSERT INTO payment (customer_id, staff_id, rental_id, amount, payment_date)
SELECT customer_id, staff_id, NULL, amount, payment_date + INTERVAL '1 year'
FROM payment;

INSERT INTO payment (customer_id, staff_id, rental_id, amount, payment_date)
SELECT customer_id, staff_id, NULL, amount, payment_date + INTERVAL '2 year'
FROM payment;

INSERT INTO payment (customer_id, staff_id, rental_id, amount, payment_date)
SELECT customer_id, staff_id, NULL, amount, payment_date + INTERVAL '3 year'
FROM payment;

INSERT INTO payment (customer_id, staff_id, rental_id, amount, payment_date)
SELECT customer_id, staff_id, NULL, amount, payment_date + INTERVAL '4 year'
FROM payment;

INSERT INTO payment (customer_id, staff_id, rental_id, amount, payment_date)
SELECT customer_id, staff_id, NULL, amount, payment_date + INTERVAL '5 year'
FROM payment;

SELECT
    (SELECT COUNT(*) FROM rental)  AS total_rentals,
    (SELECT COUNT(*) FROM payment) AS total_payments;
