#!/usr/bin/env sysbench
-- =============================================================================
-- SCRIPT SYSBENCH: oltp_read_write_sakila.lua
-- =============================================================================
-- OBJETIVO: Workload OLTP mixto lectura/escritura sobre el esquema Sakila
--           (MariaDB) o Pagila (PostgreSQL), con concurrencia controlada
--           por --threads. Pensado para los casos R2 (OLTP mixto 80/20) y
--           R5 (carga sostenida 30 min) bajo cualquiera de las 3
--           configuraciones de auditoria.
--
-- DECISION METODOLOGICA: ver header de oltp_read_only_sakila.lua.
--
-- PATRON POR TRANSACCION (18 ops, ratio ~78/22 lectura/escritura):
--   Lecturas (14 ops):
--     - 10 point SELECTs sobre rental por PK aleatorio
--     - 1 simple range sobre rental (BETWEEN de 100 filas por PK)
--     - 1 sum range sobre payment.amount
--     - 1 order range sobre rental ORDER BY rental_date
--     - 1 distinct range sobre payment DISTINCT staff_id
--   Escrituras (4 ops):
--     - 2 UPDATE rental SET return_date = CURRENT_TIMESTAMP WHERE rental_id = ?
--     - 2 UPDATE payment SET amount = amount + 0.01 WHERE payment_id = ?
--
-- EVENTOS DE AUDITORIA ESPERADOS POR TRANSACCION:
--   - C1 (baseline): 0
--   - C2 (plugin): 18 entradas en server_audit.log / postgresql.log
--     (cada query loguea events=QUERY,TABLE)
--   - C3 (triggers): 4 INSERTs en audit_*:
--       * 2 en audit_rental (de los 2 UPDATE rental, via trg_audit_rental_update)
--       * 2 en audit_payment (de los 2 UPDATE payment, via trg_audit_payment_update)
--     En PostgreSQL la auditoria de payment se reparte entre payment parent
--     y particiones hijas segun donde resida fisicamente cada fila; el
--     conteo en audit_payment es identico (cobertura simetrica documentada
--     en docs/architecture.md §3).
--
-- USO: identico a oltp_read_only_sakila.lua. Para R5 usar --time=1800.
--
-- DERIVA DE DATOS (importante para R5 sostenido):
--   Cada UPDATE rental setea return_date al timestamp actual; cada UPDATE
--   payment incrementa amount en 0.01. Sobre corridas largas (R5 con
--   ~5K txn/seg durante 30 min) los datos se polucionan acumulativamente:
--   en promedio cada payment_id recibe ~70 incrementos, su amount sube
--   ~$0.70. Entre corridas de R5 (cambio de configuracion C1->C2->C3)
--   se debe RESTAURAR snapshot de la VM o revertir los cambios para
--   que las 3 mediciones partan del mismo estado. Ver docs/cases.md §2.
-- =============================================================================

sysbench.cmdline.options = {
   point_selects = {"Numero de point SELECT por transaccion", 10},
   range_size    = {"Tamano del rango para BETWEEN (en filas)", 100}
}

function thread_init()
   drv = sysbench.sql.driver()
   con = drv:connect()

   local rs = con:query("SELECT MAX(rental_id) FROM rental")
   max_rental_id = tonumber(rs:fetch_row()[1])
   rs = con:query("SELECT MAX(payment_id) FROM payment")
   max_payment_id = tonumber(rs:fetch_row()[1])

   if max_rental_id == nil or max_payment_id == nil then
      error("No se pudo determinar MAX(rental_id)/MAX(payment_id). " ..
            "Verifique que el esquema este cargado con datos.")
   end
end

function thread_done()
   con:disconnect()
end

function event()
   local range_size = sysbench.opt.range_size
   con:query("BEGIN")

   -- ---- LECTURAS (14 ops) ----

   for i = 1, sysbench.opt.point_selects do
      local rid = sysbench.rand.uniform(1, max_rental_id)
      con:query(string.format("SELECT * FROM rental WHERE rental_id = %d", rid))
   end

   local rid = sysbench.rand.uniform(1, max_rental_id - range_size)
   con:query(string.format(
      "SELECT * FROM rental WHERE rental_id BETWEEN %d AND %d",
      rid, rid + range_size - 1))

   local pid = sysbench.rand.uniform(1, max_payment_id - range_size)
   con:query(string.format(
      "SELECT SUM(amount) FROM payment WHERE payment_id BETWEEN %d AND %d",
      pid, pid + range_size - 1))

   rid = sysbench.rand.uniform(1, max_rental_id - range_size)
   con:query(string.format(
      "SELECT * FROM rental WHERE rental_id BETWEEN %d AND %d ORDER BY rental_date",
      rid, rid + range_size - 1))

   pid = sysbench.rand.uniform(1, max_payment_id - range_size)
   con:query(string.format(
      "SELECT DISTINCT staff_id FROM payment WHERE payment_id BETWEEN %d AND %d",
      pid, pid + range_size - 1))

   -- ---- ESCRITURAS (4 ops, dispara 4 triggers de auditoria bajo C3) ----

   -- 2 UPDATE rental sobre rental_ids aleatorios distintos
   local u_rid_1 = sysbench.rand.uniform(1, max_rental_id)
   con:query(string.format(
      "UPDATE rental SET return_date = CURRENT_TIMESTAMP WHERE rental_id = %d",
      u_rid_1))

   local u_rid_2 = sysbench.rand.uniform(1, max_rental_id)
   con:query(string.format(
      "UPDATE rental SET return_date = CURRENT_TIMESTAMP WHERE rental_id = %d",
      u_rid_2))

   -- 2 UPDATE payment sobre payment_ids aleatorios distintos
   local u_pid_1 = sysbench.rand.uniform(1, max_payment_id)
   con:query(string.format(
      "UPDATE payment SET amount = amount + 0.01 WHERE payment_id = %d",
      u_pid_1))

   local u_pid_2 = sysbench.rand.uniform(1, max_payment_id)
   con:query(string.format(
      "UPDATE payment SET amount = amount + 0.01 WHERE payment_id = %d",
      u_pid_2))

   con:query("COMMIT")
end

function prepare()
   local drv = sysbench.sql.driver()
   local con = drv:connect()
   local rs = con:query("SELECT COUNT(*) FROM rental")
   print(string.format("[prepare] rental count = %s", tostring(rs:fetch_row()[1])))
   rs = con:query("SELECT COUNT(*) FROM payment")
   print(string.format("[prepare] payment count = %s", tostring(rs:fetch_row()[1])))
   con:disconnect()
end

function cleanup()
   print("[cleanup] no-op (esquema Sakila/Pagila preservado por diseno)")
end
