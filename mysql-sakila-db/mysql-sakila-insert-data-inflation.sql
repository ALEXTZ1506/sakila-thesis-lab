-- =============================================================================
-- SCRIPT: Insert Data Inflation (MariaDB)
-- OBJECTIVE: Multiply data volume to reach ~500k+ rows for stress testing.
--
-- This file applies 5 self-doubling INSERT...SELECT iterations to `rental`
-- and `payment`, raising each table from ~16K to ~513K rows (factor
-- 2^5 = 32x). No other tables are touched. The PostgreSQL mirror lives at
-- ../postgres-sakila-db/postgres-sakila-insert-data-inflation.sql and uses
-- the same logic for volumetric symmetry between both backends.
--
-- DESIGN DECISION (documented limitation, intentional):
--   Inflated `payment` rows carry rental_id = NULL. Re-associating each
--   inflated payment to its source rental would require per-row
--   LAST_INSERT_ID bookkeeping (or RETURNING in PG) that this script does
--   not perform, so leaving NULL keeps both backends symmetric. The FK
--   fk_payment_rental is ON DELETE SET NULL on a nullable column, so this
--   insertion is legal.
--
--   Consequence: analytic queries that join payment -> rental -> inventory
--   -> film will only see the original ~16K payments (1/32 of the
--   post-inflation total). This is acceptable for the thesis because the
--   audit-overhead measurements operate on row volume written and audited,
--   not on JOIN-graph completeness.
--
-- IDEMPOTENCY GUARD:
--   The script is NOT idempotent: a second run would violate the UNIQUE
--   KEY (rental_date, inventory_id, customer_id) on `rental` (same date+
--   inv+cust already exists from the previous inflation). The guard
--   procedure below aborts cleanly if `rental` already exceeds the Sakila
--   baseline, instead of failing midway through with a confusing
--   duplicate-key error.
--   To re-run, reload the base dataset first (drop-objects + schema +
--   insert-data), then run this script again.
-- =============================================================================

SET SQL_SAFE_UPDATES = 0;

-- ---------------------------------------------------------
-- GUARD: refuse to run if data has already been inflated.
-- Implemented as a one-shot stored procedure because IF/SIGNAL are only
-- valid inside stored programs in MariaDB/MySQL. The procedure is dropped
-- immediately after execution so the catalog stays clean.
-- ---------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_inflation_guard;

DELIMITER $$
CREATE PROCEDURE sp_inflation_guard()
BEGIN
    DECLARE v_count INT;
    SELECT COUNT(*) INTO v_count FROM rental;
    IF v_count > 20000 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Inflation appears to have run already (rental rows > 20000, baseline ~16044). Reload the base dataset before running this script again.';
    END IF;
END$$
DELIMITER ;

CALL sp_inflation_guard();
DROP PROCEDURE sp_inflation_guard;

-- ---------------------------------------------------------
-- STEP 1: Inflate RENTAL table
-- ---------------------------------------------------------

SELECT 'Inflating RENTAL table...' AS status;

INSERT INTO rental (rental_date, inventory_id, customer_id, return_date, staff_id, last_update)
SELECT DATE_ADD(rental_date, INTERVAL 1 YEAR), inventory_id, customer_id, DATE_ADD(return_date, INTERVAL 1 YEAR), staff_id, NOW()
FROM rental;

INSERT INTO rental (rental_date, inventory_id, customer_id, return_date, staff_id, last_update)
SELECT DATE_ADD(rental_date, INTERVAL 2 YEAR), inventory_id, customer_id, DATE_ADD(return_date, INTERVAL 2 YEAR), staff_id, NOW()
FROM rental;

INSERT INTO rental (rental_date, inventory_id, customer_id, return_date, staff_id, last_update)
SELECT DATE_ADD(rental_date, INTERVAL 3 YEAR), inventory_id, customer_id, DATE_ADD(return_date, INTERVAL 3 YEAR), staff_id, NOW()
FROM rental;

INSERT INTO rental (rental_date, inventory_id, customer_id, return_date, staff_id, last_update)
SELECT DATE_ADD(rental_date, INTERVAL 4 YEAR), inventory_id, customer_id, DATE_ADD(return_date, INTERVAL 4 YEAR), staff_id, NOW()
FROM rental;

INSERT INTO rental (rental_date, inventory_id, customer_id, return_date, staff_id, last_update)
SELECT DATE_ADD(rental_date, INTERVAL 5 YEAR), inventory_id, customer_id, DATE_ADD(return_date, INTERVAL 5 YEAR), staff_id, NOW()
FROM rental;

-- ---------------------------------------------------------
-- STEP 2: Inflate PAYMENT table
-- ---------------------------------------------------------

SELECT 'Inflating PAYMENT table...' AS status;

INSERT INTO payment (customer_id, staff_id, rental_id, amount, payment_date, last_update)
SELECT customer_id, staff_id, NULL, amount, DATE_ADD(payment_date, INTERVAL 1 YEAR), NOW()
FROM payment;

INSERT INTO payment (customer_id, staff_id, rental_id, amount, payment_date, last_update)
SELECT customer_id, staff_id, NULL, amount, DATE_ADD(payment_date, INTERVAL 2 YEAR), NOW()
FROM payment;

INSERT INTO payment (customer_id, staff_id, rental_id, amount, payment_date, last_update)
SELECT customer_id, staff_id, NULL, amount, DATE_ADD(payment_date, INTERVAL 3 YEAR), NOW()
FROM payment;

INSERT INTO payment (customer_id, staff_id, rental_id, amount, payment_date, last_update)
SELECT customer_id, staff_id, NULL, amount, DATE_ADD(payment_date, INTERVAL 4 YEAR), NOW()
FROM payment;

INSERT INTO payment (customer_id, staff_id, rental_id, amount, payment_date, last_update)
SELECT customer_id, staff_id, NULL, amount, DATE_ADD(payment_date, INTERVAL 5 YEAR), NOW()
FROM payment;

SELECT 
    (SELECT COUNT(*) FROM rental) AS total_rentals,
    (SELECT COUNT(*) FROM payment) AS total_payments;

