SELECT 
    c.customer_id,
    c.first_name,
    c.last_name,
    (SELECT COUNT(*) FROM rental r WHERE r.customer_id = c.customer_id) AS total_rentals,
    (SELECT COUNT(*) FROM rental r WHERE r.customer_id = c.customer_id AND r.return_date IS NULL) AS active_rentals,
    (SELECT SUM(amount) FROM payment p WHERE p.customer_id = c.customer_id) AS total_spent,
    (SELECT AVG(amount) FROM payment p WHERE p.customer_id = c.customer_id) AS avg_payment,
    (SELECT MAX(rental_date) FROM rental r WHERE r.customer_id = c.customer_id) AS last_rental,
    (SELECT COUNT(DISTINCT f.film_id) 
     FROM rental r 
     JOIN inventory i ON r.inventory_id = i.inventory_id 
     JOIN film f ON i.film_id = f.film_id 
     WHERE r.customer_id = c.customer_id) AS unique_films_rented
FROM customer c
WHERE c.active = 1
    AND (SELECT COUNT(*) FROM rental r WHERE r.customer_id = c.customer_id) > 10
ORDER BY total_spent DESC
LIMIT 500;