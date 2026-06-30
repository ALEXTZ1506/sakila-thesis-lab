# Arquitectura del experimento

Este documento consolida las **decisiones metodológicas no obvias** que se
tomaron al construir el laboratorio. Su propósito es preempt-ar preguntas
técnicas del tribunal y dejar trazabilidad de cada compromiso de diseño que
no es deducible leyendo solo el código.

---

## 1. Decisión metodológica central: baseline vs plugin

La tesis contrasta **dos** configuraciones de auditoría por motor, en línea
con sus objetivos (medir el impacto de habilitar el plugin oficial):

| Configuración | Plugin del motor | Qué mide |
|---|---|---|
| **C1 — Baseline** | OFF | Costo nativo del workload, sin overhead de auditoría |
| **C2 — Plugin nativo** | ON | Overhead del mecanismo oficial del motor (server_audit / pgAudit) |

Cada caso R1–R5 se ejecuta una vez en cada configuración, por motor.
Total: 5 casos × 2 configuraciones × 2 motores = **20 mediciones**.

### Cómo mapean las 4 VMs a las 2 configuraciones

El mapeo es 1:1 — cada VM es exactamente una configuración, sin triggers que
cargar ni transiciones entre estados:

| VM | Plugin | Configuración |
|---|---|---|
| TUS-MariaDB | OFF | C1 (baseline MariaDB) |
| TUS-MariaDB-Audit | ON | C2 (plugin MariaDB) |
| TUS-PostgreSQL | OFF | C1 (baseline PostgreSQL) |
| TUS-PostgreSQL-Audit | ON | C2 (plugin PostgreSQL) |

Cada caso R1–R5 se corre una vez en cada una de las 4 VMs.

### Triggers de auditoría aplicativa (implementación complementaria, NO medida)

El repositorio incluye triggers de auditoría a nivel aplicativo
(`audit_rental` / `audit_payment`, en los archivos `*-audit-triggers.sql`)
como implementación complementaria del esquema. **No forman parte de la
comparación medida:** los objetivos de la tesis evalúan los plugins oficiales
(`MariaDB Audit Plugin` y `pgAudit`). Además **no deben cargarse durante las
mediciones** — si estuvieran activos durante el baseline (C1) añadirían
overhead de escritura y contaminarían la línea base. Se conservan como
artefacto del laboratorio y posible trabajo futuro.

---

## 2. Decisiones de simetría entre motores

Para que las diferencias medidas sean atribuibles al motor (o al plugin),
y no a la implementación del laboratorio, el repositorio aplica las
siguientes decisiones de simetría:

- **Inflation espejo:** Ambos motores aplican 5 iteraciones de
  `INSERT ... SELECT` auto-duplicantes sobre `rental` y `payment`,
  alcanzando ~513K filas en cada tabla. Volumen equivalente verificado
  por conteo: 599 customers, 16,044 rentals base → 513,408 tras inflation.
- **Procedures simétricos:** Los 6 procedures de la sección extendida
  existen 1:1 en ambos motores con la misma firma y semántica
  (`sp_refresh_*`, `sp_seed_synthetic_data`, `sp_random_workload`,
  `sp_populate_extended_tables`).
- **Técnica de muestreo aleatorio compartida:** `sp_seed_synthetic_data`
  y `sp_random_workload` usan en ambos motores el patrón "offset aleatorio
  acotado por [MIN(pk), MAX(pk)] + lookup indexado + LIMIT 1", evitando
  `ORDER BY RAND() / RANDOM()` por su complejidad O(N log N) y evitando
  `TABLESAMPLE` porque no existe en MariaDB.
- **Tolerancia a colisiones simétrica:** MariaDB usa `INSERT IGNORE` +
  `ROW_COUNT()`; PostgreSQL usa `INSERT ... ON CONFLICT DO NOTHING` +
  `RETURNING ... INTO`. Ambos cuentan colisiones en `v_skipped` y reportan
  al final.
- **Triggers de auditoría aplicativa (complementarios, no medidos):**
  cobertura equivalente entre motores; ver §3.

---

## 3. ¿Por qué la cantidad de triggers de auditoría difiere entre motores?

> **Nota:** los triggers de auditoría aplicativa son una implementación
> complementaria, **no parte de la comparación medida** (ver §1). Esta sección
> documenta una asimetría del artefacto, útil solo si se inspeccionan los
> scripts `*-audit-triggers.sql`.

Es una asimetría **estructural del esquema Pagila** que se compensa con
triggers adicionales para preservar cobertura equivalente entre motores.

### El conteo exacto

| Motor | Cuenta | Desglose |
|---|---|---|
| MariaDB | **6 triggers de auditoría** | 3 eventos (INSERT/UPDATE/DELETE) × 2 tablas (rental, payment) |
| PostgreSQL | **24 triggers de auditoría** | 3 eventos × (1 tabla rental + 1 tabla payment parent + 6 tablas payment_p2007_XX) = 3 × 8 = 24 |

### Por qué la asimetría

`payment` en Sakila/MariaDB es una **tabla única no particionada**. Tres
triggers (`trg_audit_payment_insert/update/delete`) capturan todo el DML
sobre ella.

`payment` en Pagila/PostgreSQL usa el **particionamiento legacy con INHERITS
+ RULES** sobre 6 particiones hijas (`payment_p2007_01` a `payment_p2007_06`),
diseñadas originalmente para distribuir los pagos del primer semestre de
2007. La semántica de PostgreSQL es:

- Un trigger sobre `payment` parent solo dispara para filas que físicamente
  residen en la tabla parent. NO dispara cuando una `RULE DO INSTEAD`
  reescribe el INSERT a una hija, ni cuando un `UPDATE`/`DELETE` afecta
  filas que viven en las hijas.
- Para que el conjunto de triggers capture el universo completo de eventos
  (sin omitir el subconjunto que vive en las hijas), hay que **replicar los
  3 triggers en cada partición hija**: 3 × 6 = 18 triggers adicionales.

Total PostgreSQL: 3 (rental) + 3 (payment parent) + 18 (payment hijas) = 24.

### Lo que esto NO significa

- **No significa más auditoría:** una fila INSERTADA/MODIFICADA/ELIMINADA
  en payment dispara **exactamente un trigger** sin importar el motor, sin
  importar si físicamente reside en parent o en una hija. La auditoría
  resultante es funcionalmente equivalente.
- **No significa más overhead estructural:** los 18 triggers adicionales
  son metadatos en el catálogo, no operaciones extra por evento. Cada
  evento sigue ejecutando una sola inserción en `audit_payment`.
- **No es una decisión metodológica:** es la consecuencia mecánica del
  diseño de Pagila (heredado del proyecto upstream). Si Pagila no estuviera
  particionado, ambos motores tendrían 6 triggers cada uno.

### Implicación para la defensa

Si en el tribunal se cuestiona "¿por qué 24 vs 6?", la respuesta corta es:
**"misma cobertura, distinto número de objetos porque PostgreSQL replica
el trigger en cada partición física; sin estos 18 triggers PostgreSQL
auditaría solo ~97% de los eventos sobre payment, lo cual rompería la
simetría con MariaDB"**.

---

## 4. Asimetrías irresolubles documentadas

Tres asimetrías existen entre los motores que NO se pueden eliminar sin
sacrificar la utilidad del experimento. Las tres están documentadas en el
header del archivo SQL afectado.

### Asimetría #1 — Score de relevancia full-text (Q03)

- **MariaDB:** `MATCH(...) AGAINST(... IN NATURAL LANGUAGE MODE)` devuelve
  un float con escala interna del motor FULLTEXT (típicamente 0..10+).
- **PostgreSQL:** `ts_rank(fulltext, query)` devuelve un float con escala
  basada en frecuencia/proximidad de términos tsvector (típicamente 0..1).

Las dos escalas son **monotónicamente equivalentes para ORDENAR resultados**
(ambas rankean por relevancia decreciente) pero los **valores absolutos
difieren**. La tesis no puede comparar scores entre motores; sí puede
comparar el orden y el conjunto de resultados retornados.

### Asimetría #2 — SHA1 requiere extensión en PostgreSQL (Q03)

- **MariaDB:** `SHA1(text)` es función nativa.
- **PostgreSQL:** requiere la extensión `pgcrypto`. El archivo
  `postgres-sakila-db/queries/03_FullText_IO.sql` la carga con
  `CREATE EXTENSION IF NOT EXISTS pgcrypto;` (idempotente), pero la
  primera ejecución requiere privilegios de superusuario.

### Asimetría #3 — Columna last_update no existe en Pagila payment (Q04)

- **MariaDB Sakila:** `payment.last_update TIMESTAMP DEFAULT CURRENT_TIMESTAMP
  ON UPDATE CURRENT_TIMESTAMP`. La query original asigna
  `last_update = NOW()` (redundante pero explícita); el motor cuenta dos
  cambios por fila (`amount`, `last_update`).
- **PostgreSQL Pagila:** `payment` no incluye la columna `last_update`
  (decisión upstream del proyecto Pagila). La versión PG de Q04 solo
  asigna `amount`.

**Implicación:** el peso por fila en Q04 es ligeramente mayor en MariaDB.
Al reportar resultados de R2-write hay que mencionarlo. La asimetría
no se puede eliminar sin alterar el esquema upstream de alguno de los dos
motores, lo cual invalidaría el argumento de "esquemas canónicos".

---

## 5. Limitaciones conocidas

Restricciones del laboratorio que el lector debe conocer:

- **Inflated payments con `rental_id = NULL`:** Los ~497K payments inflados
  no se re-asocian a sus rentals fuente (decisión documentada en
  `*-insert-data-inflation.sql`). Las queries OLAP que joinean
  `payment → rental → inventory → film` solo ven el 1/32 original (~16K
  payments). Aceptable porque las mediciones de auditoría miden volumen
  escrito, no completitud del JOIN.
- **`sp_seed_synthetic_data` genera fechas actuales (2026):** El procedure
  produce `rental_date` y `payment_date` en `CURRENT_TIMESTAMP - d days`,
  fuera del rango del rollup (`sales_rollup_daily` cubre 2005-01-01 a
  2012-12-31). Por lo tanto, si se ejecuta `sp_populate_extended_tables`
  DESPUÉS de `sp_seed_synthetic_data`, los datos sembrados no aparecen en
  el rollup. Aceptable porque R3 no consulta el rollup.
- **Concurrencia delegada a sysbench:** R1, R2 y R5 requieren ejecución
  multi-hilo. El repositorio no implementa concurrencia en procedures
  SQL; la concurrencia se obtiene con `sysbench --threads=N` ejecutando
  los scripts Lua personalizados en
  [`../benchmark-scripts/`](../benchmark-scripts/), que apuntan
  directamente a `rental` y `payment` del esquema Sakila/Pagila para que
  el plugin (C2) audite operaciones reales sobre las tablas del dominio.
  Los scripts oficiales de sysbench (`/usr/share/sysbench/oltp_*.lua`)
  operan sobre el esquema `sbtest`, ajeno al dominio Sakila/Pagila, por lo
  que NO se usan en este experimento. Ver §6.
- **R1 (read-only) sí genera auditoría bajo C2:** el plugin SÍ captura
  SELECTs cuando se configura con `server_audit_events=QUERY` o
  `pgaudit.log='all'`. Por eso R1+C2 puede mostrar overhead aun siendo un
  workload de solo lectura (a diferencia de un enfoque basado en triggers
  `AFTER`, que no se dispararía en lecturas).
- **Q03 (FullText_IO) fuera de R1–R5:** No mapea directamente a ningún
  caso oficial; se conserva como prueba complementaria opcional del
  subsistema full-text. La tesis la menciona como evidencia adicional.
- **Bug pre-existente mitigado en `sp_seed_synthetic_data`:** Con
  `p_avg_rentals_per_day=100` y `v_when` fijo por día, el muestreo
  aleatorio puede repetir la combinación `(v_inv, v_cust)` y violar la
  UNIQUE KEY de rental (~6 colisiones esperadas en 3000 iteraciones por
  birthday paradox). Mitigado con `INSERT IGNORE` (MariaDB) /
  `ON CONFLICT DO NOTHING` (PostgreSQL) + contador `v_skipped`. Implicación:
  `p_avg_rentals_per_day` es un objetivo, no una garantía; pérdida esperada
  <1%.

---

## 6. Lo que el repositorio NO incluye (y por qué)

Para preempt-ar la pregunta "¿por qué no hay un script para sysbench?":

- **sqlmap, hydra** son herramientas externas estándares de la
  industria. Sus configuraciones por caso vivirán en `cases.md` cuando
  se diseñe la fase de seguridad, no como scripts del repo.
  Reimplementar su funcionalidad (inyección SQL, fuerza bruta) en
  scripts custom sería reinventar herramientas maduras, aumentaría la
  superficie de bugs y se vería peor ante un tribunal técnico.
- **sysbench** es dependencia externa (instalada via `apt`), pero el
  repositorio **sí incluye** scripts Lua personalizados en
  [`benchmark-scripts/`](../benchmark-scripts/) que se ejecutan CON
  sysbench. Estos scripts operan sobre las tablas reales de Sakila/Pagila
  (los oficiales usan `sbtest`), para que el plugin audite el dominio real.
  No se reimplementa el motor de concurrencia de sysbench; se aprovecha vía
  scripts custom.
- **Scripts de los casos de seguridad S1–S5** se diseñarán en una fase
  posterior; quedaron fuera del scope del primer entregable de código.
- **Resultados (CSV, gráficos, hojas de cálculo)** se generan fuera del
  repositorio y viven en el Capítulo IV de la tesis. La carpeta `results/`
  está incluida en `.gitignore`.

---

## 7. Referencias cruzadas

- Procedimientos operativos: [`setup.md`](setup.md)
- Comandos exactos por caso R: [`cases.md`](cases.md)
- Licencia del código: [`../LICENSE`](../LICENSE)
