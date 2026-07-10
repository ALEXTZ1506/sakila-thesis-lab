# Casos experimentales S1–S5 (seguridad / detección)

Este documento diseña la **fase de seguridad** de la tesis: cinco escenarios
de ataque (S1–S5) ejecutados a **nivel de base de datos** contra Sakila/Pagila,
para medir la **capacidad de detección forense** de los registros de auditoría.
Complementa a [`cases.md`](cases.md) (rendimiento R1–R5) y asume el mismo
laboratorio de 4 VMs de [`architecture.md`](architecture.md).

---

## 1. Qué se mide (y en qué se diferencia de R1–R5)

En la fase de rendimiento se midió el **costo** de auditar (throughput,
latencia: C2 vs C1). Aquí se mide el **valor** de auditar:

> Cuando ocurre un ataque, **¿qué permite ver el registro de auditoría a un
> defensor / analista forense?**

La comparación central deja de ser "cuánto cuesta" y pasa a ser **capacidad de
detección**: C1 (sin plugin) es esencialmente ciego (solo el log genérico del
motor); C2 (plugin: pgAudit / server_audit) debería capturar el evento con
detalle forense. Cruce secundario: **pgAudit vs server_audit** — cuál deja
mejor rastro.

Por eso la métrica no es un número continuo con N=5, sino una **rúbrica
cualitativa** aplicada a lo que aparece (o no) en el log tras cada ataque. El
ataque es determinista: el log lo captura o no. Se ejecuta **N=1** por celda
(con una repetición de confirmación), no N=5.

### 1.1 Marco de referencia (para peso académico)

Toda la tesis se ancla al modelo de calidad **ISO/IEC 25010**. Se evalúan dos de
sus características de calidad de producto:

| Característica ISO/IEC 25010 | Fase de la tesis |
|---|---|
| **Performance efficiency** | R1–R5 (rendimiento, ya medido) |
| **Security** — subcaracterísticas *Accountability* y *Non-repudiation* | S1–S5 (esta fase) |

La subcaracterística *Accountability / Non-repudiation* (rendición de cuentas /
no repudio) es precisamente lo que proveen los registros de auditoría: atribuir
una acción a un responsable sin que este pueda negarla. Así el tema cae dentro
de un estándar reconocido, no en criterios ad-hoc.

> **Nota de citación:** verificar edición/cláusula exacta (ISO/IEC 25010 tiene
> edición 2011 y revisión 2023). Citar la que use tu programa.

---

## 2. Rúbrica de detección

Para cada caso y cada motor se puntúa lo que el registro permite reconstruir:

| Puntaje | Nivel | Criterio |
|---|---|---|
| **2** | Capturado | El log registra el evento con **actor + sentencia + objeto + timestamp** → reconstrucción forense completa. |
| **1** | Parcial | Registra el evento pero falta un campo clave (no distingue éxito/fallo, no el objeto, no el origen, o solo un conteo agregado). |
| **0** | No capturado | El evento no aparece en el registro de auditoría. |

Campos forenses evaluados en cada entrada: **timestamp, usuario, host/origen,
tipo de evento, objeto (tabla/BD), sentencia literal, resultado (éxito/fallo)**.

> Estos campos no son arbitrarios: derivan del control **AU-3 "Content of Audit
> Records" de NIST SP 800-53** (familia *Audit and Accountability*), que define
> qué debe contener un registro de auditoría (qué evento, cuándo, dónde, origen,
> resultado, identidad del responsable). Equivalente en familia ISO: control de
> *Logging* de **ISO/IEC 27002**. La rúbrica queda así respaldada por un estándar.

**C1 (baseline)** es la **columna de control** — se ejecuta igual que C2, en las
2 VMs sin plugin. El ataque corre idéntico; luego se verifica empíricamente que
el registro de auditoría **no lo captura** (puntaje 0, o a lo sumo un error
genérico del motor sin valor forense). Esta ejecución NO es opcional: el
contraste "C1 vacío vs C2 lleno" ES el hallazgo que demuestra el valor del
plugin. Sin correr C1 no habría con qué comparar.

**Alcance total: 5 casos × 2 configuraciones × 2 motores = 20 celdas**, simétrico
con la fase de rendimiento (R1–R5). En C1 el "log" a inspeccionar es el logging
por defecto del motor (PostgreSQL: `log_statement='none'` por defecto → no
registra; MariaDB: `general_log` OFF por defecto → no registra) — de ahí el 0
esperado, que se confirma corriendo el ataque, no asumiéndolo.

---

## 3. Método de captura y reseteo

Por cada ataque:

1. **Marcar el log de auditoría** (truncar o anotar el offset de fin) antes de
   ejecutar. En C2: `server_audit.log` (MariaDB) / `postgresql-16-main.log`
   con líneas `AUDIT:` (PostgreSQL).
2. **Ejecutar el ataque** (scripts SQL de la carpeta `security/`, ver §9).
3. **Extraer el delta** del log → `results/security/S<n>_<config>_<motor>.log`.
4. **Puntuar** según la rúbrica (§2), anotar en `results/seguridad.md`.

**Reseteo de datos:**
- **S1, S2, S5** son de solo lectura / autenticación → no ensucian datos.
- **S3** crea un rol de bajo privilegio → se elimina al final del caso.
- **S4 es DESTRUCTIVO** (DROP/ALTER/CREATE USER) → se ejecuta **al final** y se
  **restaura el snapshot golden** de la VM después (los 4 snapshots existen).

**Orden recomendado por VM:** S1 → S2 → S3 → S5 → **S4** (destructivo, último) →
restaurar snapshot.

---

## 4. S1 — Inyección SQL

**Ataque:** ejecutar las consultas que produciría una inyección exitosa (a
nivel BD, sin app web: se simula el *resultado* de la inyección). Payloads
clásicos sobre tablas Sakila/Pagila:

```sql
-- Bypass de autenticación (tautología OR 1=1)
SELECT staff_id, username FROM staff
WHERE username = 'Mike' AND password = '' OR '1'='1';

-- Extracción por UNION (roba credenciales via una consulta de catálogo)
SELECT first_name, last_name FROM customer WHERE customer_id = 1
UNION SELECT username, password FROM staff;

-- Comentario para truncar la condición
SELECT * FROM customer WHERE email = 'x@x' OR 1=1 -- ' AND active = 1;
```

**Qué se inspecciona:** ¿el log registra la **sentencia maliciosa completa**
(con el `OR '1'='1'` / `UNION SELECT`) para que un analista la reconozca?

**Hallazgo esperado:** pgAudit y server_audit registran el texto de la
sentencia (ambos ~2). Matiz forense: pgAudit con `log_parameter=on` separa
parámetros; server_audit guarda el literal tal cual. C1 = 0.

---

## 5. S2 — Fuerza bruta de autenticación

**Ataque:** bucle de N (p.ej. 20) intentos de conexión con contraseña
incorrecta para un usuario conocido (`thesis`), más algunos con usuario
inexistente:

```bash
for i in $(seq 1 20); do
  mariadb -u thesis -pWRONGPASS_$i -e "SELECT 1" 2>/dev/null   # MariaDB
  # psql "host=127.0.0.1 user=thesis password=WRONGPASS_$i dbname=pagila"  # PostgreSQL
done
```

**Qué se inspecciona:** ¿el log registra los **CONNECT fallidos** con usuario,
origen y timestamp (para detectar el patrón de fuerza bruta)?

**Hallazgo esperado (clave para la tesis):** *asimetría de alcance del plugin.*
server_audit **sí** registra CONNECT (con `server_audit_events=CONNECT`) →
puntaje 2. **pgAudit NO registra conexiones fallidas** — pgAudit audita
*sentencias*, no autenticación; en PostgreSQL eso lo cubre el logging del
núcleo (`log_connections=on`), **no** el plugin. Se documenta como límite de
pgAudit y se prueba con `log_connections` on/off. C1 = 0.

---

## 6. S3 — Escalada de privilegios

**Ataque:** crear un rol de bajo privilegio y, desde él, intentar operaciones
no autorizadas:

```sql
-- Preparación (como admin)
CREATE USER lowpriv IDENTIFIED BY '...';           -- MariaDB
GRANT SELECT ON sakila.film TO lowpriv;

-- Intentos desde lowpriv (deben fallar)
GRANT ALL PRIVILEGES ON sakila.* TO lowpriv;       -- auto-elevación
SELECT * FROM staff;                                -- tabla fuera de su alcance
SET ROLE admin;                                     -- asunción de rol
```

**Qué se inspecciona:** ¿el log captura el **intento** y su resultado
(**denegado**), no solo las operaciones exitosas?

**Hallazgo esperado:** server_audit registra la sentencia aunque el motor la
rechace. pgAudit registra sentencias que llegan a ejecutarse; según en qué fase
falle el permiso, el intento denegado puede quedar **parcial** (1). Buen punto
de comparación. C1 = 0.

---

## 7. S5 — Exfiltración de datos

(S5 antes que S4 por orden de destructividad — ver §3.)

**Ataque:** lectura masiva de datos sensibles (PII de clientes):

```sql
SELECT * FROM customer;                         -- dump completo de PII
SELECT email FROM customer;                     -- cosecha de correos
-- Exfil a archivo (más concreto):
SELECT * FROM customer INTO OUTFILE '/tmp/dump.csv';   -- MariaDB
COPY customer TO '/tmp/dump.csv' CSV;                  -- PostgreSQL (como superusuario)
```

**Qué se inspecciona:** ¿el log captura **qué** se leyó (tabla/columnas) y da
idea del **volumen**?

**Hallazgo esperado (límite importante):** ambos plugins registran la
*sentencia* `SELECT`/`COPY` (objeto identificable → parcial-a-completo), pero
**ninguno registra el número de filas devueltas** — el volumen exfiltrado solo
se infiere de la sentencia, no del log. Se reporta como limitación de ambos.
C1 = 0.

---

## 8. S4 — DDL malicioso (DESTRUCTIVO — último)

**Ataque:** DDL no autorizado que un atacante usaría para sabotaje o
persistencia:

```sql
DROP TABLE payment;                             -- sabotaje / destrucción
CREATE USER attacker IDENTIFIED BY 'backdoor';  -- persistencia / backdoor
ALTER TABLE customer ADD COLUMN exfil TEXT;     -- manipulación de esquema
TRUNCATE rental;                                -- borrado masivo
```

**Qué se inspecciona:** ¿el log captura el **DDL** con el actor y la sentencia
exacta (para atribuir el sabotaje)?

**Hallazgo esperado:** ambos plugins capturan DDL bien (pgAudit CLASS=DDL;
server_audit como QUERY) → ~2. C1 = 0.

**⚠️ Reseteo:** este caso destruye objetos. Ejecutar **de último** en cada VM
y **restaurar el snapshot golden** inmediatamente después.

---

## 9. Estructura de artefactos (a construir tras aprobar este diseño)

```
security/
  s1_sql_injection.sql          # payloads S1 (idénticos para ambos motores donde aplique)
  s2_bruteforce.sh              # bucle de conexiones fallidas
  s3_privilege_escalation.sql   # prep + intentos desde lowpriv
  s4_malicious_ddl.sql          # DDL destructivo (último)
  s5_data_exfiltration.sql      # SELECT/COPY/OUTFILE masivo
  run_security.sh C1|C2 <motor> # orquestador: marca log, ejecuta, extrae delta
results/
  seguridad.md                  # bitácora + matriz de puntajes (rúbrica §2)
  security/S<n>_<config>_<motor>.log   # deltas de log crudos (evidencia)
```

---

## 10. Matriz de resultados (plantilla)

| Caso | pgAudit (PG C2) | server_audit (Maria C2) | Baseline (C1) | Nota forense |
|---|---|---|---|---|
| S1 Inyección | — | — | 0 | texto de sentencia |
| S2 Fuerza bruta | — (¿req. log_connections?) | — | 0 | CONNECT fallidos |
| S3 Escalada | — | — | 0 | intento denegado |
| S4 DDL malicioso | — | — | 0 | atribución de DDL |
| S5 Exfiltración | — | — | 0 | sin conteo de filas |

Puntaje por rúbrica §2 (0/1/2). La tesis discute: **profundidad de detección
vs alcance** (pgAudit no ve autenticación; server_audit sí) y **límites
comunes** (ninguno cuantifica el volumen leído).

---

## 11. Limitaciones y trabajo futuro

- **Alcance:** 5 casos (S1–S5), simétricos con los 5 de rendimiento (R1–R5).
  No se incluye un caso de resiliencia/recuperación como experimento aparte
  para mantener esa simetría y el alcance del título ("eficiencia y seguridad").
- **Durabilidad del registro de auditoría (trabajo futuro):** una pregunta
  abierta y valiosa es si, ante un **fallo abrupto** (corte de energía a mitad
  de operación), el registro de auditoría sobrevive **completo**. Los datos
  están protegidos por WAL/redo (fsync), pero pgAudit (log de PostgreSQL) y
  server_audit (archivo) suelen escribir *buffered* y no transaccionalmente —
  podría existir una transacción cometida cuyo registro de auditoría se perdió,
  un hueco de **no repudio** (subcaracterística de Security en ISO/IEC 25010).
  Se puede evaluar con un apagado en seco (`VBoxManage controlvm ... poweroff`)
  y snapshots golden como reset. Queda propuesto como extensión, no medido aquí.
- **Volumen exfiltrado:** ningún plugin registra el número de filas leídas
  (S5); el volumen solo se infiere de la sentencia.
