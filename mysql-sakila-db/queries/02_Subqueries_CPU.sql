-- =============================================================================
-- QUERY 02: PERFILADO PROFUNDO DE CLIENTES (MariaDB)
-- =============================================================================
-- MAPEO R        : R4 (consulta analitica compleja) - pieza COMPLEMENTARIA
-- RECURSOS       : CPU (4 subqueries correlacionadas x ~599 clientes activos
--                  = ~2400 ejecuciones de subquery por corrida).
-- CONTRAPARTE PG : ../../postgres-sakila-db/queries/02_Subqueries_CPU.sql
-- =============================================================================
-- OBJETIVO: Forzar el "problema N+1" multiplicando operaciones logicas por cliente.
--
-- NOTA SOBRE SQL_NO_CACHE (removido): ver explicacion en 01_Analytics_RAM.sql.
-- =============================================================================

SELECT
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