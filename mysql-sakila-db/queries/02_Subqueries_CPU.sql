-- =============================================================================
-- QUERY #2: DEEP CUSTOMER PROFILING (CPU STRESS)
-- Objective: Force the "N+1" problem by multiplying logical operations for each customer.
-- =============================================================================

SELECT 
    SQL_NO_CACHE,
    c.customer_id,
    
    CONCAT(UPPER(c.last_name), ', ', c.first_name, ' [', LENGTH(c.email), ']') AS client_profile,
    
    (SELECT SUM(p.amount) 
     FROM payment p 
     WHERE p.customer_id = c.customer_id) AS total_lifetime_value,
    
    (SELECT f.title 
     FROM rental r 
     JOIN inventory i ON r.inventory_id = i.inventory_id 
     JOIN film f ON i.film_id = f.film_id 
     WHERE r.customer_id = c.customer_id 
     ORDER BY f.length DESC, f.title ASC 
     LIMIT 1) AS longest_rental_choice,
     
    (SELECT COUNT(DISTINCT fc.category_id) 
     FROM rental r 
     JOIN inventory i ON r.inventory_id = i.inventory_id 
     JOIN film_category fc ON i.film_id = fc.film_id 
     WHERE r.customer_id = c.customer_id) AS category_diversity_index,
     
    (SELECT AVG(DATEDIFF(r.return_date, r.rental_date)) 
     FROM rental r 
     WHERE r.customer_id = c.customer_id 
       AND r.return_date IS NOT NULL) AS avg_return_delay_days

FROM customer c
WHERE c.active = 1
ORDER BY total_lifetime_value DESC;