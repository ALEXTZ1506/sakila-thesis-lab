-- =============================================================================
-- QUERY 04: TRANSACCION DE UPDATE MASIVO (PostgreSQL)
-- =============================================================================
-- MAPEO R        : R2 (OLTP mixto 80/20) - pieza COMPLEMENTARIA del componente
--                  WRITE. Permite medir overhead de auditoria sobre UPDATE
--                  masivo (~26K filas en baseline, mas tras inflation), donde
--                  cada fila afectada dispara trg_audit_payment_update via
--                  fn_audit_row() en parent o en la particion hija respectiva.
-- RECURSOS       : Write (row locks en payment + sus particiones, escritura
--                  al WAL, ejecucion masiva de triggers de auditoria).
-- CONTRAPARTE MY : ../../mysql-sakila-db/queries/04_BulkUpdate_Write.sql
-- =============================================================================
-- OBJETIVO: Forzar locks de fila masivos y saturar la auditoria con UPDATEs.
--
-- DIFERENCIAS RESPECTO A LA VERSION MARIADB:
--   * Sintaxis UPDATE multi-tabla: PostgreSQL usa UPDATE <t> SET ... FROM <t2>
--     JOIN <t3> ... WHERE en vez de UPDATE <t> JOIN <t2> SET ... WHERE.
--   * NO se asigna last_update porque la tabla payment en Pagila NO tiene esa
--     columna (asimetria estructural Sakila vs Pagila; en MariaDB existe y
--     se actualiza automaticamente via ON UPDATE CURRENT_TIMESTAMP al
--     modificar amount, por lo que la asignacion explicita en MariaDB es
--     redundante). Resultado: la version MariaDB hace 2 cambios por fila
--     (amount y last_update) y la version PostgreSQL solo 1 (amount).
--     Implicacion para la medicion: el peso de la query es ligeramente
--     mayor en MariaDB; reportarlo al comparar.
--   * c.active = 1 funciona porque Pagila preserva la columna integer
--     'active' ademas de la booleana 'activebool' (convencion Pagila).
--
-- COBERTURA SOBRE PARTICIONES (payment_p2007_01..06):
--   El UPDATE en payment parent afecta filas en parent y en las 6 hijas via
--   herencia. Los 21 triggers de la familia payment (3 en parent + 18 en
--   hijas) capturan TODOS los eventos UPDATE sin asimetria respecto a la
--   tabla un-particionada de MariaDB.
-- =============================================================================

UPDATE payment p
SET amount = amount * 1.05
FROM customer c
JOIN address a  ON c.address_id = a.address_id
JOIN city ci    ON a.city_id    = ci.city_id
WHERE p.customer_id = c.customer_id
  AND c.active      = 1
  AND ci.country_id BETWEEN 1 AND 100;
