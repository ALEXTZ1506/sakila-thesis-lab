#!/usr/bin/env sysbench
-- =============================================================================
-- SCRIPT SYSBENCH: oltp_read_only_sakila.lua
-- =============================================================================
-- OBJETIVO: Workload OLTP solo lectura sobre el esquema Sakila (MariaDB) o
--           Pagila (PostgreSQL), con concurrencia controlada por --threads.
--           Pensado para el caso R1 de la tesis (y para el componente
--           read-only de R5).
--
-- DECISION METODOLOGICA:
--   Los scripts oficiales oltp_*.lua de sysbench operan sobre el esquema
--   sbtest (tablas que crea sysbench prepare), ortogonal a Sakila/Pagila
--   y por lo tanto fuera del alcance del plugin de auditoria sobre las
--   tablas del dominio. Para que las mediciones R1 bajo el plugin (C2)
--   auditen el workload real sobre rental y payment, este script imita la
--   estructura del oltp_read_only.lua oficial pero apunta directamente a
--   esas tablas.
--
-- PATRON POR TRANSACCION (14 SELECTs, sin escrituras):
--   - 10 point SELECTs sobre rental por PK aleatorio
--   - 1 simple range sobre rental (BETWEEN de 100 filas por PK)
--   - 1 sum range sobre payment.amount
--   - 1 order range sobre rental ORDER BY rental_date
--   - 1 distinct range sobre payment DISTINCT staff_id
--
-- EVENTOS DE AUDITORIA ESPERADOS POR TRANSACCION:
--   - C1 (baseline): 0
--   - C2 (plugin): 14 entradas en server_audit.log / postgresql.log
--     (cada SELECT se loguea con events=QUERY,TABLE)
--   (Nota: el plugin C2 SI audita SELECTs. Los triggers de auditoria
--    aplicativa son implementacion complementaria, NO medida -- ver
--    docs/architecture.md §1.)
--
-- USO:
--   # MariaDB
--   sysbench benchmark-scripts/oltp_read_only_sakila.lua \
--     --db-driver=mysql \
--     --mysql-host=<IP> --mysql-user=thesis --mysql-password='<pwd>' \
--     --mysql-db=sakila \
--     --threads=10 --time=60 --report-interval=5 --histogram=on \
--     run
--
--   # PostgreSQL: --db-driver=pgsql + --pgsql-* + --pgsql-db=pagila
--
-- LIMITACIONES CONOCIDAS:
--   * Las queries usan string.format en lugar de prepared statements, lo
--     cual reduce throughput absoluto vs scripts oficiales. NO afecta la
--     comparacion relativa entre C1 y C2 (el overhead de format es
--     identico en ambas configuraciones).
--   * MAX(rental_id) y MAX(payment_id) se capturan UNA VEZ por thread al
--     inicio. R1 es read-only, asi que no hay nuevos IDs durante la
--     corrida -- no requiere refresco.
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

   -- 10 point SELECTs sobre rental por PK aleatorio
   for i = 1, sysbench.opt.point_selects do
      local rid = sysbench.rand.uniform(1, max_rental_id)
      con:query(string.format("SELECT * FROM rental WHERE rental_id = %d", rid))
   end

   -- 1 simple range sobre rental
   local rid = sysbench.rand.uniform(1, max_rental_id - range_size)
   con:query(string.format(
      "SELECT * FROM rental WHERE rental_id BETWEEN %d AND %d",
      rid, rid + range_size - 1))

   -- 1 sum range sobre payment.amount
   local pid = sysbench.rand.uniform(1, max_payment_id - range_size)
   con:query(string.format(
      "SELECT SUM(amount) FROM payment WHERE payment_id BETWEEN %d AND %d",
      pid, pid + range_size - 1))

   -- 1 order range sobre rental ORDER BY rental_date
   rid = sysbench.rand.uniform(1, max_rental_id - range_size)
   con:query(string.format(
      "SELECT * FROM rental WHERE rental_id BETWEEN %d AND %d ORDER BY rental_date",
      rid, rid + range_size - 1))

   -- 1 distinct range sobre payment DISTINCT staff_id
   pid = sysbench.rand.uniform(1, max_payment_id - range_size)
   con:query(string.format(
      "SELECT DISTINCT staff_id FROM payment WHERE payment_id BETWEEN %d AND %d",
      pid, pid + range_size - 1))

   con:query("COMMIT")
end

function prepare()
   -- Verificacion: confirma que el esquema esta cargado. NO crea ni
   -- modifica tablas (Sakila/Pagila se cargan via docs/setup.md).
   local drv = sysbench.sql.driver()
   local con = drv:connect()
   local rs = con:query("SELECT COUNT(*) FROM rental")
   print(string.format("[prepare] rental count = %s", tostring(rs:fetch_row()[1])))
   rs = con:query("SELECT COUNT(*) FROM payment")
   print(string.format("[prepare] payment count = %s", tostring(rs:fetch_row()[1])))
   con:disconnect()
end

function cleanup()
   -- No-op deliberado: el esquema Sakila/Pagila NO se debe dropear ni
   -- truncar entre corridas.
   print("[cleanup] no-op (esquema Sakila/Pagila preservado por diseno)")
end
