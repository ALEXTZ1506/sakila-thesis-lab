-- =============================================================================
-- QUERY 04: TRANSACCION DE UPDATE MASIVO (MariaDB)
-- =============================================================================
-- MAPEO R        : R2 (OLTP mixto 80/20) - pieza COMPLEMENTARIA del componente
--                  WRITE. Permite medir overhead de auditoria sobre UPDATE
--                  masivo (~26K filas en baseline, mas tras inflation), donde
--                  cada fila afectada dispara trg_audit_payment_update.
-- RECURSOS       : Write (row locks en payment, escritura a binlog/WAL,
--                  ejecucion masiva de triggers de auditoria).
-- CONTRAPARTE PG : ../../postgres-sakila-db/queries/04_BulkUpdate_Write.sql
-- =============================================================================
-- OBJETIVO: Forzar locks de fila masivos y saturar la auditoria con UPDATEs.
-- =============================================================================

UPDATE payment p
JOIN customer c ON p.customer_id = c.customer_id
JOIN address a ON c.address_id = a.address_id
JOIN city ci ON a.city_id = ci.city_id
SET
    p.amount = p.amount * 1.05,
    p.last_update = NOW()
WHERE
    c.active = 1
    AND ci.country_id BETWEEN 1 AND 100;