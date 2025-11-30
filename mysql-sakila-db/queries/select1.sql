SELECT 
    c.country,
    ci.city,
    s.store_id,
    cat.name AS category,
    YEAR(r.rental_date) AS year,
    MONTH(r.rental_date) AS month,
    COUNT(DISTINCT r.rental_id) AS rental_count,
    COUNT(DISTINCT r.customer_id) AS unique_customers,
    SUM(p.amount) AS total_revenue,
    AVG(p.amount) AS avg_payment,
    MAX(p.amount) AS max_payment,
    COUNT(DISTINCT f.film_id) AS unique_films,
    COUNT(DISTINCT a.actor_id) AS unique_actors
FROM rental r
    JOIN payment p ON r.rental_id = p.rental_id
    JOIN customer cu ON r.customer_id = cu.customer_id
    JOIN inventory i ON r.inventory_id = i.inventory_id
    JOIN film f ON i.film_id = f.film_id
    JOIN film_category fc ON f.film_id = fc.film_id
    JOIN category cat ON fc.category_id = cat.category_id
    JOIN film_actor fa ON f.film_id = fa.film_id
    JOIN actor a ON fa.actor_id = a.actor_id
    JOIN store s ON i.store_id = s.store_id
    JOIN address ad ON s.address_id = ad.address_id
    JOIN city ci ON ad.city_id = ci.city_id
    JOIN country c ON ci.country_id = c.country_id
WHERE r.rental_date BETWEEN '2005-01-01' AND '2006-02-01'
GROUP BY c.country, ci.city, s.store_id, cat.name, YEAR(r.rental_date), MONTH(r.rental_date)
HAVING COUNT(DISTINCT r.rental_id) > 5
ORDER BY total_revenue DESC, rental_count DESC
LIMIT 1000;