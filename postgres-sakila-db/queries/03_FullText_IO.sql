-- =============================================================================
-- QUERY 03: BUSQUEDA FULL-TEXT Y CRUNCHING DE STRINGS (PostgreSQL)
-- =============================================================================
-- MAPEO R        : Ninguno directamente - stress complementario fuera de R1-R5.
--                  Se conserva como evidencia auxiliar del subsistema full-text;
--                  la tesis la menciona como prueba opcional.
-- RECURSOS       : I/O sobre indice GIST de film.fulltext, CPU para hashing
--                  (SHA1 via pgcrypto) y manipulacion de strings.
-- CONTRAPARTE MY : ../../mysql-sakila-db/queries/03_FullText_IO.sql
-- =============================================================================
-- OBJETIVO: Estresar el subsistema full-text (tsvector + GIST) y la CPU
--           procesando strings, contraparte simetrica del stress equivalente
--           en MariaDB (que usa FULLTEXT sobre film_text MyISAM).
--
-- DIFERENCIAS RESPECTO A LA VERSION MARIADB:
--   * MATCH(ft.title, ft.description) AGAINST(...) IN NATURAL LANGUAGE MODE
--     -> f.fulltext @@ to_tsquery('english', 'term1 | term2 | ...').
--     Pagila guarda el indice full-text como columna tsvector en film, no
--     como tabla auxiliar film_text+FULLTEXT como en Sakila, asi que la JOIN
--     con film_text se elimina. Los operadores | replican la semantica OR-like
--     de NATURAL LANGUAGE MODE (cualquier termino matchea).
--   * Score de relevancia: MATCH AGAINST devuelve un float; en PG usamos
--     ts_rank(f.fulltext, query) que devuelve un float con escala distinta
--     pero monotonicamente equivalente (ordena igual los resultados).
--   * SHA1(text) -> encode(digest(text,'sha1'),'hex') via pgcrypto.
--     pgcrypto se carga al inicio con CREATE EXTENSION IF NOT EXISTS
--     (idempotente; requiere privilegios de superusuario la primera vez).
--   * REVERSE() y SUBSTRING() funcionan en ambos motores con misma semantica.
--
-- GESTION DE CACHE: ver nota en 01_Analytics_RAM.sql.
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

SELECT
    f.title,

    ts_rank(f.fulltext, to_tsquery('english', 'action | adventure | drama | love | war | robot')) AS relevance_score,

    encode(digest(CONCAT(f.title, f.description), 'sha1'), 'hex') AS content_signature,
    REVERSE(SUBSTRING(f.description, 5, 20)) AS nonsense_processing,

    (SELECT COUNT(*) FROM inventory i WHERE i.film_id = f.film_id) AS physical_copies_count

FROM film f
WHERE
    f.fulltext @@ to_tsquery('english', 'action | adventure | drama | love | war | robot')

ORDER BY relevance_score DESC, content_signature ASC;
