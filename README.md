# sakila-thesis-lab

Laboratorio reproducible para la tesis **"Eficiencia y seguridad en el uso
de registros de auditoría en bases de datos relacionales: estudio
comparativo entre MariaDB y PostgreSQL"** — Universidad Laica Eloy Alfaro
de Manabí (ULEAM), Ecuador, 2026.

## Cómo citar este repositorio

```bibtex
@misc{lainez2026sakilathesislab,
  author       = {Lainez Tomala, Joffre Alex},
  title        = {sakila-thesis-lab: Laboratorio comparativo de auditoría
                  en MariaDB y PostgreSQL},
  year         = {2026},
  publisher    = {ULEAM},
  howpublished = {\url{https://github.com/<usuario>/sakila-thesis-lab}}
}
```

Cita en prosa: *Lainez Tomala, J. A. (2026). sakila-thesis-lab:
Laboratorio comparativo de auditoría en MariaDB y PostgreSQL. ULEAM.*

## Contexto

La tesis contrasta el costo y la utilidad forense de **tres
configuraciones de auditoría** sobre dos motores de bases de datos
relacionales, usando el esquema canónico Sakila (MariaDB) / Pagila
(PostgreSQL) inflado a ~500K filas en las tablas de hechos:

- **C1 — Baseline** (sin auditoría)
- **C2 — Plugin nativo del motor** (server_audit en MariaDB, pgAudit en PostgreSQL)
- **C3 — Triggers aplicativos** sobre tablas `audit_rental` / `audit_payment`

Sobre 5 casos de rendimiento (R1–R5) y 5 casos de seguridad (S1–S5, en
fase posterior), midiendo overhead y cobertura.

## Arquitectura del experimento

Cuatro VMs Ubuntu 22.04 LTS sobre VirtualBox cubren la dimensión
"plugin sí/no"; la dimensión "triggers sí/no" se controla cargando o no
el archivo `*-audit-triggers.sql`.

```
                MariaDB 11.4                  PostgreSQL 16
            ┌────────────────┐             ┌────────────────┐
            │  TUS-MariaDB   │             │ TUS-PostgreSQL │   (sin plugin)
            └────────────────┘             └────────────────┘
            ┌────────────────┐             ┌────────────────┐
            │TUS-MariaDB-Audit│             │TUS-PostgreSQL-Audit│ (con plugin)
            └────────────────┘             └────────────────┘
```

Detalle metodológico completo en [`docs/architecture.md`](docs/architecture.md).

## Estructura del repositorio

```
sakila-thesis-lab/
├── LICENSE                                       MIT
├── README.md                                     este archivo
├── .gitignore
├── docs/
│   ├── architecture.md                           decisiones metodologicas
│   ├── setup.md                                  instalacion y carga
│   └── cases.md                                  comandos por caso R
├── mysql-sakila-db/
│   ├── mysql-sakila-schema.sql                   schema + extended tables/procs
│   ├── mysql-sakila-insert-data.sql              datos canonicos Sakila
│   ├── mysql-sakila-insert-data-inflation.sql    inflation 32x
│   ├── mysql-sakila-extend-audit.sql             ALTER retroactivos
│   ├── mysql-sakila-audit-triggers.sql           6 triggers aplicativos (C3)
│   ├── mysql-sakila-delete-data.sql              limpieza de datos
│   ├── mysql-sakila-drop-objects.sql             drop de objetos
│   └── queries/                                  4 queries por recurso
├── postgres-sakila-db/
│   ├── postgres-sakila-schema.sql                schema + extended tables/procs
│   ├── postgres-sakila-insert-data.sql           datos canonicos (formato INSERT)
│   ├── postgres-sakila-insert-data-using-copy.sql datos canonicos (formato COPY, recomendado)
│   ├── postgres-sakila-insert-data-inflation.sql inflation 32x
│   ├── postgres-sakila-extend-audit.sql          ALTER retroactivos
│   ├── postgres-sakila-audit-triggers.sql        24 triggers aplicativos (C3)
│   ├── postgres-sakila-delete-data.sql           limpieza de datos
│   ├── postgres-sakila-drop-objects.sql          drop de objetos
│   └── queries/                                  4 queries equivalentes
└── benchmark-scripts/
    ├── oltp_read_only_sakila.lua                 sysbench R1
    └── oltp_read_write_sakila.lua                sysbench R2 y R5
```

## Quick start

Carga completa en una VM MariaDB (procedimiento detallado en
[`docs/setup.md`](docs/setup.md)):

```bash
cd mysql-sakila-db
mariadb -u thesis -p sakila < mysql-sakila-schema.sql
mariadb -u thesis -p sakila < mysql-sakila-insert-data.sql
mariadb -u thesis -p sakila < mysql-sakila-insert-data-inflation.sql
mariadb -u thesis -p sakila < mysql-sakila-audit-triggers.sql   # solo para C3
mariadb -u thesis -p sakila -e "CALL sp_populate_extended_tables();"
```

Carga completa en una VM PostgreSQL:

```bash
cd postgres-sakila-db
psql -U thesis -d pagila -f postgres-sakila-schema.sql
psql -U thesis -d pagila -f postgres-sakila-insert-data-using-copy.sql
psql -U thesis -d pagila -f postgres-sakila-insert-data-inflation.sql
psql -U thesis -d pagila -f postgres-sakila-audit-triggers.sql   # solo para C3
psql -U thesis -d pagila -c "CALL sp_populate_extended_tables();"
```

## Casos experimentales

| Caso | Descripción | Herramienta |
|---|---|---|
| R1 | OLTP solo lectura, concurrencia 1/10/50/100 | sysbench `oltp_read_only` |
| R2 | OLTP mixto 80/20 R/W | sysbench `oltp_read_write` + Q04 |
| R3 | Inserción masiva sobre Sakila/Pagila | `CALL sp_seed_synthetic_data(...)` |
| R4 | Consulta analítica compleja | Q01 (principal), Q02 (complementaria) |
| R5 | Carga sostenida 10 min | sysbench `--time=600` |

Comandos exactos en [`docs/cases.md`](docs/cases.md).

## Limitaciones conocidas

- Concurrencia para R1/R2/R5 se obtiene con sysbench externo
  ejecutando los scripts Lua personalizados de `benchmark-scripts/`,
  que apuntan a las tablas auditadas de Sakila/Pagila.
- R1+C3 produce métricas equivalentes a R1+C1 porque los triggers
  no capturan SELECTs; se reporta como finding cualitativo, no gap.
- Inflated payments tienen `rental_id = NULL` por diseño; queries OLAP
  joinando `payment → rental → ...` solo ven el 1/32 original.
- PostgreSQL tiene 24 triggers de auditoría vs 6 en MariaDB; es
  cobertura equivalente, no más auditoría — ver `docs/architecture.md` §3.

Lista completa en [`docs/architecture.md`](docs/architecture.md) §5.

## Dependencias de versiones

| Componente | Versión |
|---|---|
| Ubuntu Server | 22.04 LTS |
| MariaDB | 11.4 LTS |
| PostgreSQL | 16 |
| sysbench | 1.0.20 |
| sqlmap, hydra | versión empacada en Ubuntu 22.04 |

Comandos de instalación en [`docs/setup.md`](docs/setup.md) §2.

## Licencia

[MIT](LICENSE). Copyright © 2026 Joffre Alex Lainez Tomala.

## Autor y contacto

**Joffre Alex Lainez Tomala**
Estudiante de pregrado, ULEAM — Ecuador
Email: a.lainez@mcmteam.agency
