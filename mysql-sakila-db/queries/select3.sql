SELECT 
    ft.film_id,
    ft.title,
    ft.description,
    MATCH(ft.title, ft.description) AGAINST('action adventure drama love war' IN NATURAL LANGUAGE MODE) AS relevance_score,
    f.rental_rate,
    f.rating,
    (SELECT COUNT(*) FROM inventory i WHERE i.film_id = ft.film_id) AS copies_available,
    (SELECT COUNT(*) FROM rental r 
     JOIN inventory i ON r.inventory_id = i.inventory_id 
     WHERE i.film_id = ft.film_id AND r.return_date IS NULL) AS currently_rented
FROM film_text ft
    JOIN film f ON ft.film_id = f.film_id
WHERE MATCH(ft.title, ft.description) AGAINST('action adventure drama love war' IN NATURAL LANGUAGE MODE) > 0
    AND f.rating IN ('PG', 'PG-13', 'R')
ORDER BY relevance_score DESC, f.rental_rate DESC
LIMIT 200;