-- =============================================================================
-- SCRIPT: Insert Data Inflation
-- OBJECTIVE: Multiply data volume to reach ~500k+ rows for stress testing.
-- =============================================================================

SET SQL_SAFE_UPDATES = 0;

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

