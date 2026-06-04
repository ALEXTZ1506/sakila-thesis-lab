-- =============================================================================
-- QUERY 03: BUSQUEDA FULL-TEXT Y CRUNCHING DE STRINGS (MariaDB)
-- =============================================================================
-- MAPEO R        : Ninguno directamente - stress complementario fuera de R1-R5.
--                  Se conserva como evidencia auxiliar del subsistema full-text;
--                  la tesis la menciona como prueba opcional.
-- RECURSOS       : I/O (FULLTEXT sobre film_text MyISAM), CPU para hashing
--                  (SHA1) y manipulacion de strings (REVERSE, SUBSTRING).
-- CONTRAPARTE PG : ../../postgres-sakila-db/queries/03_FullText_IO.sql
-- =============================================================================
-- OBJETIVO: Estresar el subsistema full-text (MyISAM) y la CPU procesando strings.
--
-- NOTA SOBRE SQL_NO_CACHE (removido): ver explicacion en 01_Analytics_RAM.sql.
-- =============================================================================

SELECT
    f.title,
    
    MATCH(ft.title, ft.description) AGAINST('action adventure drama love war robot' IN NATURAL LANGUAGE MODE) AS relevance_score,
    
    SHA1(CONCAT(f.title, ft.description)) AS content_signature,
    REVERSE(SUBSTRING(ft.description, 5, 20)) AS nonsense_processing,
    
    (SELECT COUNT(*) FROM inventory i WHERE i.film_id = f.film_id) AS physical_copies_count

FROM film_text ft
JOIN film f ON ft.film_id = f.film_id
WHERE 
    MATCH(ft.title, ft.description) AGAINST('action adventure drama love war robot' IN NATURAL LANGUAGE MODE)
    
ORDER BY relevance_score DESC, content_signature ASC;