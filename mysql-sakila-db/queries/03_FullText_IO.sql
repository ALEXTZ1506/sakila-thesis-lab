-- =============================================================================
-- QUERY #3: FULL-TEXT SEARCH AND STRING CRUNCHING
-- Objective: Stress the file subsystem (MyISAM/InnoDB) and burn CPU processing strings.
-- =============================================================================

SELECT 
    SQL_NO_CACHE,
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