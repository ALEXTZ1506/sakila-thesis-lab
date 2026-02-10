-- =============================================================================
-- QUERY #4: BULK UPDATE TRANSACTION STRESS
-- Objective: Force massive row locking and audit log I/O saturation.
-- =============================================================================

UPDATE payment p
JOIN customer c ON p.customer_id = c.customer_id
JOIN address a ON c.address_id = a.address_id
JOIN city ci ON a.city_id = ci.city_id
SET
    p.amount = p.amount * 1.05,
    p.last_update = NOW()
WHERE
    c.active = 1
    AND ci.country_id BETWEEN 1 AND 100;