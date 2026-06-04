-- =============================================================================
-- QUERY 01: ANALISIS FINANCIERO POR PAIS, CIUDAD, TIENDA, CATEGORIA Y MES (PostgreSQL)
-- =============================================================================
-- MAPEO R        : R4 (consulta analitica compleja) - pieza PRINCIPAL
-- RECURSOS       : RAM (work_mem para sort por GROUP BY de 6 columnas + ORDER BY),
--                  I/O en tablas de hechos (rental, payment), CPU moderado.
-- CONTRAPARTE MY : ../../mysql-sakila-db/queries/01_Analytics_RAM.sql
-- =============================================================================
-- OBJETIVO: Saturar memoria de trabajo con 12 JOINs (13 tablas) y forzar sort en disco.
--
-- DIFERENCIAS RESPECTO A LA VERSION MARIADB:
--   * YEAR(x) / MONTH(x) -> EXTRACT(YEAR FROM x) / EXTRACT(MONTH FROM x)
--   * HAVING usa la expresion COUNT(DISTINCT r.rental_id) > 5 directamente
--     porque PostgreSQL no resuelve aliases de SELECT en HAVING.
--   * STDDEV existe en ambos motores (alias de STDDEV_POP). Compatible 1:1.
--   * Resto del SQL es ANSI; sin reescrituras adicionales.
--
-- GESTION DE CACHE: ver nota en la version MariaDB. En PostgreSQL se vacia
-- el buffer pool con reinicio del servicio o pg_buffercache + DISCARD ALL.
-- =============================================================================

SELECT
    c.country,
    ci.city,
    s.store_id,
    cat.name AS category,
    EXTRACT(YEAR  FROM r.rental_date)::INT AS year,
    EXTRACT(MONTH FROM r.rental_date)::INT AS month,

    COUNT(DISTINCT r.rental_id)    AS rental_count,
    COUNT(DISTINCT r.customer_id)  AS unique_customers,
    SUM(p.amount)                  AS total_revenue,
    AVG(p.amount)                  AS avg_payment,
    STDDEV(p.amount)               AS payment_volatility,
    CONCAT(c.country, ' - ', ci.city, ' (', cat.name, ')') AS location_tag

FROM rental r
    JOIN payment p        ON r.rental_id    = p.rental_id
    JOIN customer cu      ON r.customer_id  = cu.customer_id
    JOIN inventory i      ON r.inventory_id = i.inventory_id
    JOIN film f           ON i.film_id      = f.film_id
    JOIN film_category fc ON f.film_id      = fc.film_id
    JOIN category cat     ON fc.category_id = cat.category_id
    JOIN film_actor fa    ON f.film_id      = fa.film_id
    JOIN actor a          ON fa.actor_id    = a.actor_id
    JOIN store s          ON i.store_id     = s.store_id
    JOIN address ad       ON s.address_id   = ad.address_id
    JOIN city ci          ON ad.city_id     = ci.city_id
    JOIN country c        ON ci.country_id  = c.country_id

GROUP BY
    c.country, ci.city, s.store_id, cat.name,
    EXTRACT(YEAR FROM r.rental_date), EXTRACT(MONTH FROM r.rental_date)
HAVING COUNT(DISTINCT r.rental_id) > 5
ORDER BY total_revenue DESC, rental_count DESC;
