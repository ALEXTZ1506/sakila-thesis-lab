# Setup del entorno experimental

Este documento describe cómo levantar las 4 VMs desde cero hasta dejarlas
listas para ejecutar los casos R1–R5 descritos en
[`cases.md`](cases.md). El laboratorio asume las decisiones metodológicas
documentadas en [`architecture.md`](architecture.md).

---

## 1. Prerrequisitos

- **Host:** VirtualBox 7.0+ con extensiones instaladas.
- **Recursos sugeridos por VM:** 4 vCPU, 4 GB RAM, 30 GB disco. Los
  resultados dependen del hardware del host; documente sus
  especificaciones al reportar mediciones.
- **Red:** las 4 VMs en la misma red interna o en bridge mode, con
  conectividad recíproca y acceso a internet para instalar paquetes.
- **Imagen base:** Ubuntu Server 22.04 LTS (la versión exacta utilizada
  en la tesis se documenta en §2).

---

## 2. Versiones exactas utilizadas

| Componente | Versión | Notas |
|---|---|---|
| Ubuntu Server | 24.04.x LTS | x86_64 (lab validado en 24.04 LTS) |
| MariaDB | 11.4.x LTS | Repositorio oficial de MariaDB |
| PostgreSQL | 16.x | Nativo en Ubuntu 24.04 (apt); PGDG solo para otra versión |
| MariaDB Audit Plugin | empacado con MariaDB 11.4 | `server_audit.so` |
| pgAudit | 16.0+ (paquete `postgresql-16-pgaudit`) | Repositorio PGDG |
| sysbench | 1.0.20 | Paquete oficial de Ubuntu (`apt install sysbench`) |
| sqlmap | versión empacada en Ubuntu 24.04 | Para los casos S1–S5 (fase futura) |
| hydra | versión empacada en Ubuntu 24.04 | Para los casos S1–S5 (fase futura) |

> Al reportar resultados, registre las versiones puntuales (`mariadb --version`,
> `psql --version`, `sysbench --version`) en la bitácora de cada VM.

---

## 3. Instalación de MariaDB 11.4 (TUS-MariaDB y TUS-MariaDB-Audit)

Ejecutar en cada VM MariaDB:

```bash
# 1. Importar firma del repositorio oficial MariaDB
sudo apt update
sudo apt install -y curl gnupg apt-transport-https
curl -LsSf https://r.mariadb.com/downloads/mariadb_repo_setup \
  | sudo bash -s -- --mariadb-server-version="mariadb-11.4"

# 2. Instalar servidor y cliente
sudo apt update
sudo apt install -y mariadb-server mariadb-client

# 3. Verificar
mariadb --version    # Espera "mariadb ... 11.4.x ..."
sudo systemctl status mariadb
```

Crear el usuario de aplicación (ajustar la contraseña en cada VM; los
ejemplos usan un placeholder):

```sql
-- Conectado como root via socket:
sudo mariadb
CREATE USER 'thesis'@'%' IDENTIFIED BY '<placeholder-pwd>';
GRANT ALL PRIVILEGES ON sakila.* TO 'thesis'@'%';
FLUSH PRIVILEGES;
```

---

## 4. Instalación de PostgreSQL 16 (TUS-PostgreSQL y TUS-PostgreSQL-Audit)

Ejecutar en cada VM PostgreSQL:

```bash
# 1. Agregar repositorio PGDG
sudo apt install -y curl ca-certificates
sudo install -d /usr/share/postgresql-common/pgdg
sudo curl -o /usr/share/postgresql-common/pgdg/apt.postgresql.org.asc \
  --fail https://www.postgresql.org/media/keys/ACCC4CF8.asc
sudo sh -c 'echo "deb [signed-by=/usr/share/postgresql-common/pgdg/apt.postgresql.org.asc] \
  https://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" \
  > /etc/apt/sources.list.d/pgdg.list'

# 2. Instalar servidor, cliente y contrib (contiene pgcrypto requerido por Q03)
sudo apt update
sudo apt install -y postgresql-16 postgresql-client-16 postgresql-contrib-16

# 3. Verificar
psql --version    # Espera "psql (PostgreSQL) 16.x"
sudo systemctl status postgresql
```

> **Ubuntu 24.04:** PostgreSQL 16 es el paquete nativo del repositorio de
> Ubuntu, así que puede **omitir el paso 1 (PGDG)** e instalar directamente
> `sudo apt install -y postgresql-16 postgresql-client-16`. PGDG solo hace
> falta para una versión distinta a la del repositorio. `pgcrypto` (para Q03)
> viene incluido en `postgresql-16`; `postgresql-contrib-16` es un paquete de
> transición vacío en versiones recientes.

Crear el usuario y la base de datos:

```bash
sudo -u postgres psql <<EOF
CREATE USER thesis WITH PASSWORD '<placeholder-pwd>';
CREATE DATABASE pagila OWNER thesis;
EOF
```

> **Nota:** PostgreSQL no crea la base de datos automáticamente. El nombre
> `pagila` es convención; ajústelo si su VM usa otro nombre.

### 4.1. Acceso remoto (para sysbench y clientes en la red del laboratorio)

Por defecto PostgreSQL solo escucha en `127.0.0.1`; un cliente externo
(sysbench, psql remoto) no podrá conectar. Para habilitar acceso desde la
red interna del laboratorio:

```bash
# Escuchar en todas las interfaces
sudo sed -i "s/^#\?listen_addresses.*/listen_addresses = '*'/" \
  /etc/postgresql/16/main/postgresql.conf

# Permitir al rol thesis desde la subred del lab (ajuste el CIDR a su red)
echo "host    pagila    thesis    192.168.1.0/24    scram-sha-256" \
  | sudo tee -a /etc/postgresql/16/main/pg_hba.conf

sudo systemctl restart postgresql
sudo ss -tlnp | grep 5432        # debe mostrar 0.0.0.0:5432, no 127.0.0.1
```

Verifique desde el cliente: `psql -h <IP-VM> -U thesis -d pagila -c "SELECT 1;"`.
(El análogo en MariaDB es `bind-address = 0.0.0.0` en el `.cnf`.)

---

## 5. Configuración del plugin de auditoría

### 5.1. MariaDB Audit Plugin en TUS-MariaDB-Audit

```sql
sudo mariadb
INSTALL SONAME 'server_audit';
SHOW PLUGINS;     -- Confirme que 'SERVER_AUDIT' aparece como ACTIVE
```

Editar `/etc/mysql/mariadb.conf.d/50-server.cnf` y agregar al bloque
`[mariadbd]`:

```ini
server_audit_logging       = ON
server_audit_events        = CONNECT,QUERY,TABLE
server_audit_output_type   = FILE
server_audit_file_path     = /var/log/mariadb/server_audit.log
server_audit_file_rotate_size = 100M
server_audit_file_rotations   = 9
```

Crear el directorio de logs con permisos correctos:

```bash
sudo mkdir -p /var/log/mariadb
sudo chown mysql:mysql /var/log/mariadb
sudo systemctl restart mariadb
```

### 5.2. pgAudit en TUS-PostgreSQL-Audit

```bash
sudo apt install -y postgresql-16-pgaudit
```

Editar `/etc/postgresql/16/main/postgresql.conf`:

```ini
shared_preload_libraries = 'pgaudit'
pgaudit.log              = 'all'
pgaudit.log_catalog      = off
pgaudit.log_relation     = on
pgaudit.log_parameter    = on
```

Reiniciar y verificar:

```bash
sudo systemctl restart postgresql
sudo -u postgres psql -d pagila -c "CREATE EXTENSION IF NOT EXISTS pgaudit;"
```

Los logs de pgAudit se mezclan con los logs estándar de PostgreSQL
(`/var/log/postgresql/postgresql-16-main.log`) prefijados con `AUDIT:`.

---

## 6. Carga de datos en MariaDB

Orden estricto de scripts (ver [`architecture.md`](architecture.md) §1 para
saber cuándo cargar o no `mysql-sakila-audit-triggers.sql`):

```bash
cd mysql-sakila-db

# 6.1. Esquema base (crea sakila, tablas estándar + extendidas, procedures)
mariadb -u thesis -p sakila < mysql-sakila-schema.sql

# 6.2. Datos canónicos de Sakila (~16K rentals, ~16K payments)
mariadb -u thesis -p sakila < mysql-sakila-insert-data.sql

# 6.3. Inflation a ~513K rentals y ~513K payments (factor 32x)
mariadb -u thesis -p sakila < mysql-sakila-insert-data-inflation.sql

# 6.4. (Solo si la VM se cargó antes de la migracion de TIMESTAMP(6) +
#       actor_host) Aplicar ALTER TABLE retroactivos
mariadb -u thesis -p sakila < mysql-sakila-extend-audit.sql

# 6.5. (Solo para configuracion C3) Crear los 6 triggers de auditoria
#       aplicativa. NO ejecutar para mediciones C1 (baseline) o C2 (plugin).
mariadb -u thesis -p sakila < mysql-sakila-audit-triggers.sql

# 6.6. Poblar tablas extendidas (sales_rollup_daily, customer_kpis,
#       inventory_status). Opcional para R1-R5 (ninguno las consulta) pero
#       recomendado por completitud.
mariadb -u thesis -p sakila -e "CALL sp_populate_extended_tables();"
```

---

## 7. Carga de datos en PostgreSQL

> **Método de conexión (importante).** El usuario del sistema operativo no es
> `thesis`, así que la autenticación `peer` por socket falla; hay que conectar
> por TCP con `-h localhost` (auth `scram`, pide contraseña). Para no repetirla
> en cada archivo: `export PGPASSWORD='<placeholder-pwd>'` durante la carga y
> `unset PGPASSWORD` al terminar.
>
> **Quién carga qué.** El esquema y el inflation se cargan como `thesis` (para
> que `thesis` quede **dueño** de las tablas, necesario para sysbench y para
> los triggers de C3). Los **datos** se cargan como `postgres` (superusuario)
> porque el archivo hace `ALTER TABLE ... DISABLE TRIGGER ALL`, operación
> reservada a superusuario; las filas entran igual en las tablas de `thesis`
> sin cambiar la propiedad.

```bash
cd postgres-sakila-db
export PGPASSWORD='<placeholder-pwd>'

# 7.1. Esquema base (como thesis). Veras ~54 errores "must be able to SET ROLE
#      postgres": son los ALTER ... OWNER TO postgres del dump, INOFENSIVOS —
#      cada CREATE si se aplica y el objeto queda propiedad de thesis.
psql -h localhost -U thesis -d pagila -f postgres-sakila-schema.sql

# 7.2. Datos canonicos COMO POSTGRES (superusuario; requiere DISABLE TRIGGER ALL).
#      Hay dos variantes: (a) postgres-sakila-insert-data.sql (INSERT, 7.8 MB);
#      (b) postgres-sakila-insert-data-using-copy.sql (COPY, 2.6 MB, 10-100x mas
#      rapida). Se recomienda (b).
sudo -u postgres psql -d pagila -f postgres-sakila-insert-data-using-copy.sql

# 7.3. Inflation a ~513K rentals y ~513K payments (como thesis)
psql -h localhost -U thesis -d pagila -f postgres-sakila-insert-data-inflation.sql

# 7.4. (Solo si la VM se cargo antes de la migracion de actor_host)
psql -h localhost -U thesis -d pagila -f postgres-sakila-extend-audit.sql

# 7.5. (Solo para configuracion C3) Crear los 24 triggers de auditoria
#       aplicativa. NO ejecutar para mediciones C1 o C2.
psql -h localhost -U thesis -d pagila -f postgres-sakila-audit-triggers.sql

# 7.6. Poblar tablas extendidas
psql -h localhost -U thesis -d pagila -c "CALL sp_populate_extended_tables();"

unset PGPASSWORD
```

---

## 8. Verificación post-carga (datos)

Conteos esperados tras schema + insert-data + inflation:

```sql
-- MariaDB y PostgreSQL (misma query, mismos numeros esperados)
SELECT 'customer' AS tabla, COUNT(*) AS filas FROM customer
UNION ALL SELECT 'inventory', COUNT(*) FROM inventory
UNION ALL SELECT 'rental',    COUNT(*) FROM rental
UNION ALL SELECT 'payment',   COUNT(*) FROM payment;
```

Resultados esperados:

| tabla | filas | notas |
|---|---|---|
| customer | 599 | base Sakila |
| inventory | 4,581 | base Sakila |
| rental | 513,408 | 16,044 × 32 (inflation 5 iteraciones) |
| payment | 513,568 | 16,049 × 32 |

Si los conteos coinciden, el setup de datos está completo.

---

## 9. Verificación de mecanismos de auditoría

### 9.1. Triggers aplicativos (solo si se ejecutó `*-audit-triggers.sql`)

```sql
-- MariaDB
SELECT TRIGGER_NAME, EVENT_OBJECT_TABLE, ACTION_TIMING, EVENT_MANIPULATION
FROM information_schema.TRIGGERS
WHERE TRIGGER_SCHEMA = 'sakila' AND TRIGGER_NAME LIKE 'trg_audit_%'
ORDER BY EVENT_OBJECT_TABLE, EVENT_MANIPULATION;
-- Espera: 6 filas
```

```sql
-- PostgreSQL
SELECT tgrelid::regclass AS tabla, tgname
FROM pg_trigger
WHERE tgname LIKE 'trg_audit_%' AND NOT tgisinternal
ORDER BY 1, 2;
-- Espera: 24 filas (3 sobre rental + 21 sobre payment+particiones)
```

Prueba funcional: insertar una fila de prueba y verificar la auditoría:

```sql
-- MariaDB
SELECT COUNT(*) FROM audit_rental;          -- N antes
INSERT INTO rental (rental_date, inventory_id, customer_id, return_date, staff_id)
VALUES (NOW(), 1, 1, NULL, 1);
SELECT COUNT(*) FROM audit_rental;          -- N+1 esperado
SELECT * FROM audit_rental ORDER BY audit_id DESC LIMIT 1;
```

```sql
-- PostgreSQL
SELECT COUNT(*) FROM audit_rental;          -- N antes
INSERT INTO rental (rental_date, inventory_id, customer_id, return_date, staff_id)
VALUES (CURRENT_TIMESTAMP, 1, 1, NULL, 1);
SELECT COUNT(*) FROM audit_rental;          -- N+1 esperado
SELECT * FROM audit_rental ORDER BY audit_id DESC LIMIT 1;
```

La fila nueva en `audit_rental` debe tener `action='INSERT'`, `actor_user`
poblado, `actor_host` poblado, y `after_json` con el JSON serializado.

### 9.2. Plugin del motor

```sql
-- MariaDB Audit Plugin (en TUS-MariaDB-Audit)
SHOW VARIABLES LIKE 'server_audit%';
-- server_audit_logging debe ser ON
```

```bash
# Disparar un evento auditable y verificar que aparezca en el log
sudo tail -f /var/log/mariadb/server_audit.log
# En otra terminal:
mariadb -u thesis -p sakila -e "SELECT COUNT(*) FROM rental;"
# El tail debe mostrar la entrada del evento.
```

```sql
-- pgAudit (en TUS-PostgreSQL-Audit)
SHOW shared_preload_libraries;     -- debe contener 'pgaudit'
SELECT * FROM pg_extension WHERE extname = 'pgaudit';
```

```bash
# Disparar y verificar el log
sudo tail -f /var/log/postgresql/postgresql-16-main.log
# En otra terminal:
psql -U thesis -d pagila -c "SELECT COUNT(*) FROM rental;"
# El tail debe mostrar la linea con prefijo 'AUDIT:'.
```

---

## 10. Herramientas externas

```bash
# sysbench (en el host o en una VM cliente; usado para R1, R2, R5)
sudo apt install -y sysbench
sysbench --version

# sqlmap (para fase de seguridad S1-S5, futuro)
sudo apt install -y sqlmap

# hydra (para fase de seguridad S1-S5, futuro)
sudo apt install -y hydra
```

> Los scripts Lua personalizados que se ejecutan con sysbench viven en
> [`benchmark-scripts/`](../benchmark-scripts/) del repositorio. Apuntan
> directamente a `sakila.rental`/`sakila.payment` (MariaDB) y
> `pagila.rental`/`pagila.payment` (PostgreSQL) en lugar del esquema
> `sbtest` de sysbench oficial. Ver [`cases.md`](cases.md) §3–§7 para
> los comandos exactos por caso.

---

## 11. Estrategia de cache entre mediciones

Para que las corridas sean comparables, el buffer pool / shared_buffers
debe estar **frío** o **caliente de forma reproducible** entre runs.
Recomendación: reiniciar el servicio antes de cada corrida.

```bash
# MariaDB
sudo systemctl restart mariadb
# Esperar unos segundos a que acepte conexiones
mariadb -u thesis -p -e "SELECT 1;"

# PostgreSQL
sudo systemctl restart postgresql
sudo -u postgres psql -d pagila -c "SELECT 1;"
```

Como complemento dentro de la sesión:

```sql
-- MariaDB
FLUSH TABLES;
RESET QUERY CACHE;   -- en MariaDB 11.4 el query cache esta deshabilitado;
                     -- la sentencia no falla y queda como practica defensiva.
```

```sql
-- PostgreSQL
DISCARD ALL;         -- limpia plan cache + prepared statements de la sesion
-- shared_buffers solo se vacia reiniciando el servicio.
```

No hay necesidad de usar `SQL_NO_CACHE` ni equivalente per-query: el query
cache de MariaDB 11.4 está deshabilitado por defecto y PostgreSQL no
cachea resultados de queries.

---

## 12. Troubleshooting común

- **`fk_payment_rental` falla al cargar `mysql-sakila-insert-data.sql`:**
  asegúrese de haber ejecutado primero `mysql-sakila-schema.sql` y de
  estar conectado al schema `sakila` (`USE sakila;`).
- **`CREATE EXTENSION pgcrypto` falla con "permission denied":** el rol
  `thesis` no es superusuario. Conéctese como `postgres` la primera vez
  para crear la extensión, después puede volver al rol `thesis`.
- **Inflation aborta con "Inflation appears to have run already":** el
  guard detectó que `rental` ya tiene >20,000 filas. Recargue el dataset
  base (drop-objects + schema + insert-data) antes de re-ejecutar el
  inflation.
- **Los triggers no disparan en PostgreSQL para payments con fechas
  2007-01..06:** comprobado, es comportamiento esperado del particionamiento
  legacy de Pagila. Los 18 triggers sobre las hijas cubren esos casos.
  Ver [`architecture.md`](architecture.md) §3.
- **`SHOW server_audit_logging` retorna OFF:** verifique que
  `server_audit_logging=ON` está bajo `[mariadbd]` (no `[client]` ni otra
  sección) y que el servicio se reinició tras editar el `.cnf`.
