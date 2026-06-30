# Casos experimentales R1–R5

Este documento da los comandos exactos para reproducir cada caso de
rendimiento en cada una de las 3 configuraciones de auditoría
(C1 baseline / C2 plugin / C3 triggers aplicativos). Asume que el setup
descrito en [`setup.md`](setup.md) está completo y que las decisiones
metodológicas de [`architecture.md`](architecture.md) son aceptadas.

---

## 1. Las 3 configuraciones de auditoría

| Configuración | VM (MariaDB / PostgreSQL) | Plugin | Triggers aplicativos |
|---|---|---|---|
| **C1 — Baseline** | TUS-MariaDB / TUS-PostgreSQL | OFF | OFF |
| **C2 — Plugin nativo** | TUS-MariaDB-Audit / TUS-PostgreSQL-Audit | ON | OFF |
| **C3 — Triggers aplicativos** | TUS-MariaDB / TUS-PostgreSQL | OFF | ON |

C1 y C3 conviven en la misma VM (la sin-plugin). La transición entre ellos:

```bash
# C1 -> C3 (en TUS-MariaDB)
mariadb -u thesis -p sakila < mysql-sakila-db/mysql-sakila-audit-triggers.sql

# C3 -> C1 (en TUS-MariaDB)
mariadb -u thesis -p sakila <<'EOF'
DROP TRIGGER IF EXISTS trg_audit_rental_insert;
DROP TRIGGER IF EXISTS trg_audit_rental_update;
DROP TRIGGER IF EXISTS trg_audit_rental_delete;
DROP TRIGGER IF EXISTS trg_audit_payment_insert;
DROP TRIGGER IF EXISTS trg_audit_payment_update;
DROP TRIGGER IF EXISTS trg_audit_payment_delete;
TRUNCATE audit_rental;
TRUNCATE audit_payment;
EOF
```

```bash
# C1 -> C3 (en TUS-PostgreSQL)
psql -U thesis -d pagila -f postgres-sakila-db/postgres-sakila-audit-triggers.sql

# C3 -> C1 (en TUS-PostgreSQL)
psql -U thesis -d pagila <<'EOF'
DROP TRIGGER IF EXISTS trg_audit_rental_insert  ON rental;
DROP TRIGGER IF EXISTS trg_audit_rental_update  ON rental;
DROP TRIGGER IF EXISTS trg_audit_rental_delete  ON rental;
DROP TRIGGER IF EXISTS trg_audit_payment_insert ON payment;
DROP TRIGGER IF EXISTS trg_audit_payment_update ON payment;
DROP TRIGGER IF EXISTS trg_audit_payment_delete ON payment;
-- Tambien sobre las 6 particiones hijas:
DO $$ DECLARE p TEXT;
BEGIN
  FOREACH p IN ARRAY ARRAY['payment_p2007_01','payment_p2007_02','payment_p2007_03',
                           'payment_p2007_04','payment_p2007_05','payment_p2007_06'] LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS trg_audit_payment_insert ON %I', p);
    EXECUTE format('DROP TRIGGER IF EXISTS trg_audit_payment_update ON %I', p);
    EXECUTE format('DROP TRIGGER IF EXISTS trg_audit_payment_delete ON %I', p);
  END LOOP;
END $$;
DROP FUNCTION IF EXISTS fn_audit_row();
TRUNCATE audit_rental;
TRUNCATE audit_payment;
EOF
```

---

## 2. Procedimiento estándar por medición

Para cada (caso R, motor, configuración):

1. **Reset de cache.** Reiniciar el servicio (ver
   [`setup.md`](setup.md) §11). Espere a que acepte conexiones.
2. **Reset de datos (solo R3 y R5).** Restaurar snapshot de la VM o
   revertir los cambios DML acumulados de la corrida anterior. R3
   acumula nuevos rentals/payments en fechas 2026+; R5 incrementa
   `payment.amount` y reescribe `rental.return_date` aleatoriamente.
   Sin este reset, las 3 mediciones por configuración partirían de
   estados distintos. R1, R2 y R4 también modifican datos pero el
   impacto es marginal en corridas cortas (60 seg).
3. **Capturar estado inicial.** Conteos de `audit_rental` / `audit_payment`,
   tamaño del log del plugin, plan de la query si aplica (ver §8).
4. **Ejecutar el caso.** Comando exacto en las secciones §3–§7.
5. **Capturar estado final.** Mismas métricas que en (3).
6. **Repetir.** N corridas por caso (la tesis sugiere N≥5 para
   estabilizar p50/p95). Cada corrida en archivo separado.
7. **Guardar.** `results/<R>_<config>_<motor>_runK.log` (la carpeta
   `results/` está en `.gitignore` y vive solo en el host de análisis,
   no en las VMs).

---

## 3. R1 — Carga OLTP solo lectura con concurrencia variable

**Herramienta:** sysbench con script Lua personalizado
[`benchmark-scripts/oltp_read_only_sakila.lua`](../benchmark-scripts/oltp_read_only_sakila.lua).
Apunta directamente a las tablas `rental` y `payment` del esquema
Sakila (MariaDB) o Pagila (PostgreSQL) para que las mediciones bajo C3
(triggers aplicativos) reflejen el workload sobre tablas auditadas.
Decisión metodológica completa en
[`architecture.md`](architecture.md) §5.

**Verificación inicial (opcional, una sola vez por motor):**

```bash
# MariaDB
sysbench benchmark-scripts/oltp_read_only_sakila.lua \
  --db-driver=mysql \
  --mysql-host=<TUS-MariaDB-IP> \
  --mysql-user=thesis --mysql-password='<placeholder-pwd>' \
  --mysql-db=sakila \
  prepare

# PostgreSQL
sysbench benchmark-scripts/oltp_read_only_sakila.lua \
  --db-driver=pgsql \
  --pgsql-host=<TUS-PostgreSQL-IP> \
  --pgsql-user=thesis --pgsql-password='<placeholder-pwd>' \
  --pgsql-db=pagila \
  prepare
```

(El `prepare` aquí no crea tablas; solo imprime conteos de rental y
payment para confirmar que el esquema está cargado.)

**Ejecución** (repetir con `--threads={1,10,50,100}`):

```bash
sysbench benchmark-scripts/oltp_read_only_sakila.lua \
  --db-driver=mysql \
  --mysql-host=<IP> --mysql-user=thesis --mysql-password='<pwd>' \
  --mysql-db=sakila \
  --threads=10 \
  --time=60 \
  --report-interval=5 \
  --histogram=on \
  run
```

**Sin limpieza:** el esquema Sakila/Pagila NO se dropea ni se trunca
entre corridas (el `cleanup` del script es no-op por diseño). Para
resetear el conteo de eventos auditados en C3, ejecutar manualmente
`TRUNCATE audit_rental; TRUNCATE audit_payment;` entre cambios de
configuración.

> **Finding esperado R1+C3 (no es un gap, es un resultado):** la
> métrica R1+C3 será **prácticamente idéntica a R1+C1** porque los
> triggers `AFTER INSERT/UPDATE/DELETE` no se disparan en SELECTs.
> R1 es read-only, por lo tanto no hay eventos auditables a nivel
> aplicativo. Esto se reporta en la tesis como **evidencia cualitativa
> de una limitación intrínseca del mecanismo trigger-based**: a
> diferencia de los plugins (que SÍ capturan SELECTs), la auditoría
> aplicativa no puede instrumentar operaciones de lectura.

---

## 4. R2 — Carga OLTP mixta 80/20 R/W

**Herramienta primaria:** sysbench con script Lua personalizado
[`benchmark-scripts/oltp_read_write_sakila.lua`](../benchmark-scripts/oltp_read_write_sakila.lua).
Patrón por transacción: 14 lecturas + 4 escrituras = 18 ops/txn con
ratio aproximado 78/22. Las 4 escrituras (2 UPDATE rental + 2 UPDATE
payment) disparan 4 triggers de auditoría aplicativa bajo C3.

```bash
sysbench benchmark-scripts/oltp_read_write_sakila.lua \
  --db-driver=mysql \
  --mysql-host=<IP> --mysql-user=thesis --mysql-password='<pwd>' \
  --mysql-db=sakila \
  --threads=10 \
  --time=60 \
  --report-interval=5 \
  run
```

(Cambiar a `--db-driver=pgsql` + `--pgsql-*` + `--pgsql-db=pagila`
para PostgreSQL.)

**Pieza complementaria** — Query 04 ejecutada directamente sobre
Sakila/Pagila para medir el costo de un UPDATE masivo single-shot
(~26K filas en baseline; varia con inflation) además del workload
mixto:

```bash
# MariaDB
time mariadb -u thesis -p sakila < mysql-sakila-db/queries/04_BulkUpdate_Write.sql

# PostgreSQL
time psql -U thesis -d pagila -f postgres-sakila-db/queries/04_BulkUpdate_Write.sql
```

Reportar ambas mediciones por separado en la tesis: el script Lua
mide overhead de auditoría bajo carga concurrente sostenida, Q04 mide
overhead bajo una sola operación masiva (perfiles complementarios).

---

## 5. R3 — Inserción masiva

**Herramienta:** `sp_seed_synthetic_data` ejecutado directamente sobre
Sakila/Pagila (no requiere sysbench).

```bash
# MariaDB
time mariadb -u thesis -p sakila \
  -e "CALL sp_seed_synthetic_data(0, 30, 200);"

# PostgreSQL
time psql -U thesis -d pagila \
  -c "CALL sp_seed_synthetic_data(0, 30, 200);"
```

Parámetros sugeridos:
- `p_customers=0`: no genera nuevos customers (mantiene el universo de
  599 clientes para que las corridas sean comparables).
- `p_days=30`: 30 días sintéticos hacia atrás desde la fecha actual.
- `p_avg_rentals_per_day=200`: ~6,000 rentals + ~6,000 payments + UPDATEs
  intermedios = ~13,000 operaciones DML por corrida.

Ajuste `p_avg_rentals_per_day` para escalar el volumen (200 → 1,000 da
~65,000 ops; advierta que la probabilidad de colisión sube con avg≥500 y
revise el contador `v_skipped` que el procedure reporta al final).

> Para que las corridas R3 entre configuraciones sean comparables, debe
> revertir el estado de rental/payment entre runs. Lo más simple es
> restaurar un snapshot de la VM tras el inflation; alternativamente,
> `DELETE FROM rental WHERE rental_date > '2012-12-31';` + `DELETE FROM
> payment WHERE payment_date > '2012-12-31';` elimina solo lo sembrado.

---

## 6. R4 — Consulta analítica compleja

**Herramienta:** queries directas sobre Sakila/Pagila.

**Pieza principal** — Query 01:

```bash
# MariaDB
time mariadb -u thesis -p sakila --table < mysql-sakila-db/queries/01_Analytics_RAM.sql

# PostgreSQL
time psql -U thesis -d pagila -f postgres-sakila-db/queries/01_Analytics_RAM.sql
```

**Pieza complementaria** — Query 02:

```bash
# MariaDB
time mariadb -u thesis -p sakila --table < mysql-sakila-db/queries/02_Subqueries_CPU.sql

# PostgreSQL
time psql -U thesis -d pagila -f postgres-sakila-db/queries/02_Subqueries_CPU.sql
```

Para capturar el plan de ejecución (recomendado en al menos una corrida
por configuración):

```bash
# MariaDB
mariadb -u thesis -p sakila -e \
  "EXPLAIN FORMAT=JSON $(cat mysql-sakila-db/queries/01_Analytics_RAM.sql | grep -v '^--' | tr '\n' ' ')"

# PostgreSQL
psql -U thesis -d pagila -c "EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON) \
$(cat postgres-sakila-db/queries/01_Analytics_RAM.sql | grep -v '^--')"
```

---

## 7. R5 — Carga sostenida 10 minutos

**Herramienta:** mismo script Lua que R2
([`oltp_read_write_sakila.lua`](../benchmark-scripts/oltp_read_write_sakila.lua))
con `--time=600` y concurrencia fija.

```bash
sysbench benchmark-scripts/oltp_read_write_sakila.lua \
  --db-driver=mysql \
  --mysql-host=<IP> --mysql-user=thesis --mysql-password='<pwd>' \
  --mysql-db=sakila \
  --threads=50 \
  --time=600 \
  --report-interval=30 \
  run
```

`--report-interval=30` genera reporte cada 30 segundos, útil para
detectar deriva (drift) de latencia durante la corrida sostenida.

> **Importante para R5: deriva acumulativa de datos.** Cada UPDATE
> rental setea `return_date = CURRENT_TIMESTAMP` y cada UPDATE payment
> incrementa `amount` en 0.01. Sobre 10 min a ~5K txn/seg, cada
> payment_id recibe ~23 incrementos en promedio (deriva de ~$0.23 por
> payment). **Entre las 3 corridas de R5 (una por configuración) se
> debe restaurar snapshot de la VM o revertir los cambios**, para que
> las 3 mediciones partan del mismo estado. Ver §2 y header del script
> Lua para detalles.

---

## 8. Captura de métricas durante la ejecución

### 8.1. Tiempo de ejecución

- **MariaDB CLI:** el cliente reporta `X rows in set (Y sec)` tras cada
  query. Para timing en script, usar `time` de shell envolviendo el
  comando. Para profiling detallado:
  ```sql
  SET profiling = 1;
  -- ejecutar la query
  SHOW PROFILES;
  SHOW PROFILE FOR QUERY 1;
  ```
- **PostgreSQL CLI:** activar `\timing on` antes de la query. Para
  desglose interno:
  ```sql
  EXPLAIN (ANALYZE, BUFFERS, TIMING ON) <query>;
  ```

### 8.2. Logs del plugin de auditoría

Antes y después del caso, capture tamaño y línea final del log:

```bash
# MariaDB Audit Plugin
sudo wc -l /var/log/mariadb/server_audit.log
sudo tail -n 5 /var/log/mariadb/server_audit.log
# (caso ejecutado)
sudo wc -l /var/log/mariadb/server_audit.log    # delta = eventos auditados
```

```bash
# pgAudit (mezclado con log estandar de PostgreSQL)
sudo grep -c 'AUDIT:' /var/log/postgresql/postgresql-16-main.log
# (caso ejecutado)
sudo grep -c 'AUDIT:' /var/log/postgresql/postgresql-16-main.log
```

### 8.3. Crecimiento de tablas audit_rental / audit_payment

Solo aplica en C3 (triggers aplicativos):

```sql
SELECT COUNT(*) AS audit_rental_filas FROM audit_rental;
SELECT COUNT(*) AS audit_payment_filas FROM audit_payment;
-- (ejecutar el caso)
SELECT COUNT(*) FROM audit_rental;     -- delta = eventos auditados por triggers
SELECT COUNT(*) FROM audit_payment;
```

Para tamaño físico:

```sql
-- MariaDB
SELECT TABLE_NAME, ROUND(DATA_LENGTH/1024/1024, 2) AS data_mb,
       ROUND(INDEX_LENGTH/1024/1024, 2) AS index_mb
FROM information_schema.TABLES
WHERE TABLE_SCHEMA='sakila' AND TABLE_NAME LIKE 'audit_%';
```

```sql
-- PostgreSQL
SELECT relname, pg_size_pretty(pg_total_relation_size(oid)) AS total_size
FROM pg_class WHERE relname IN ('audit_rental', 'audit_payment');
```

### 8.4. Organización de resultados

Convención sugerida (carpeta local, no se versiona — está en `.gitignore`):

```
results/
├── R1_C1_mariadb_run1.log
├── R1_C1_mariadb_run2.log
├── R1_C2_mariadb_run1.log
├── R1_C3_mariadb_run1.log
├── R1_C1_postgres_run1.log
└── ...
```

El **procesamiento estadístico** (medias, desviaciones, percentiles,
gráficos) se hace **fuera del repositorio** en hojas de cálculo o
notebook externo. Los resultados consolidados van al Capítulo IV de la
tesis.

---

## 9. Mapeo recíproco queries ↔ R

| Archivo | Mapeo R | Rol |
|---|---|---|
| `queries/01_Analytics_RAM.sql` (Maria + PG) | R4 | Principal |
| `queries/02_Subqueries_CPU.sql` (Maria + PG) | R4 | Complementaria |
| `queries/03_FullText_IO.sql` (Maria + PG) | — | Stress complementario fuera de R1–R5 |
| `queries/04_BulkUpdate_Write.sql` (Maria + PG) | R2 | Componente write |
| `sp_seed_synthetic_data` (procedure) | R3 | Principal |
| `sp_random_workload` (procedure) | R2/R5 | Carga mixta complementaria |
| sysbench `oltp_read_only.lua` | R1 | Principal (driver externo) |
| sysbench `oltp_read_write.lua` | R2/R5 | Principal (driver externo) |

---

## 10. Notas sobre Q03 (FullText_IO)

Q03 no mapea directamente a ningún caso R1–R5. Se conserva como **prueba
complementaria opcional** del subsistema full-text. La tesis la menciona
como evidencia auxiliar; ejecutarla es opcional pero recomendado para
documentar comportamiento del FULLTEXT (MariaDB) vs tsvector+GIST
(PostgreSQL) bajo cada configuración de auditoría.

```bash
# MariaDB
time mariadb -u thesis -p sakila --table < mysql-sakila-db/queries/03_FullText_IO.sql

# PostgreSQL (la primera ejecucion crea la extension pgcrypto)
time psql -U thesis -d pagila -f postgres-sakila-db/queries/03_FullText_IO.sql
```

Asimetrías entre motores documentadas en
[`architecture.md`](architecture.md) §4.
