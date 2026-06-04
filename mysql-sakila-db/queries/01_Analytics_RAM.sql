-- =============================================================================
-- QUERY 01: ANALISIS FINANCIERO POR PAIS, CIUDAD, TIENDA, CATEGORIA Y MES (MariaDB)
-- =============================================================================
-- MAPEO R        : R4 (consulta analitica compleja) - pieza PRINCIPAL
-- RECURSOS       : RAM (sort en disco por GROUP BY de 6 columnas + ORDER BY),
--                  I/O en tablas de hechos (rental, payment), CPU moderado.
-- CONTRAPARTE PG : ../../postgres-sakila-db/queries/01_Analytics_RAM.sql
-- =============================================================================
-- OBJETIVO: Saturar RAM con 12 JOINs (13 tablas) y forzar sort en disco.
--
-- NOTA SOBRE SQL_NO_CACHE (removido):
--   El hint SQL_NO_CACHE solo invalida el query cache (resultados cacheados),
--   no el InnoDB buffer pool que es el cache real para benchmarks de lectura.
--   MariaDB 11.4 tiene el query cache desactivado por defecto y en proceso
--   de deprecacion, asi que el hint es funcionalmente nulo. La gestion de
--   cache para mediciones se hace a nivel de configuracion del motor
--   (my.cnf) + reinicio del servicio entre runs, lo cual mantiene simetria
--   con PostgreSQL (donde no existe hint equivalente y se usa el mismo
--   approach).
-- =============================================================================

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
    STDDEV(p.amount) AS payment_volatility, 
    CONCAT(c.country, ' - ', ci.city, ' (', cat.name, ')') AS location_tag
    
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
    
GROUP BY 
    c.country, ci.city, s.store_id, cat.name, YEAR(r.rental_date), MONTH(r.rental_date)
HAVING rental_count > 5 
ORDER BY total_revenue DESC, rental_count DESC;