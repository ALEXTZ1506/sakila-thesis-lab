# Runbook operativo de mediciones R1–R5

Este documento es la **guía de ejecución** que une [`setup.md`](setup.md)
(cómo dejar las VMs listas), [`cases.md`](cases.md) (comandos exactos por
caso) y [`architecture.md`](architecture.md) (por qué del diseño). Responde
a: *en qué orden corro, cuántas veces, con qué sesiones y qué capturo*.

No reemplaza a los otros docs: los referencia. Si un comando exacto no está
aquí, está en [`cases.md`](cases.md) §3–§7.

---

## 1. Antes de empezar (una sola vez por VM)

Checklist condensado de [`setup.md`](setup.md):

1. **4 VMs levantadas** con las versiones de [`setup.md`](setup.md) §2
   (MariaDB 11.4, PostgreSQL 16, Ubuntu 24.04).
2. **Datos cargados e inflados** → verificar los conteos de
   [`setup.md`](setup.md) §8: `rental = 513,408`, `payment = 513,568`.
   Si no cuadran, no continuar.
3. **Plugins configurados** solo en las VMs `-Audit` ([`setup.md`](setup.md) §5).
4. **sysbench instalado en el CLIENTE** (host o VM cliente), no en las VMs
   de base de datos ([`setup.md`](setup.md) §10).
5. **Conectividad remota verificada.** sysbench corre desde el cliente
   apuntando a la VM por red; confirmar que el motor escucha fuera de
   `localhost`:
   - MariaDB: `bind-address = 0.0.0.0` en el `.cnf`.
   - PostgreSQL: `listen_addresses = '*'` en `postgresql.conf` + regla en
     `pg_hba.conf` para el rol `thesis` desde la IP del cliente.
   - Prueba: `mariadb -h <IP> -u thesis -p -e "SELECT 1;"` y
     `psql -h <IP> -U thesis -d pagila -c "SELECT 1;"` desde el cliente.
6. **Snapshot "golden" de cada VM en VirtualBox**, tomado *después* de cargar
   datos y *antes* de la primera corrida. Es un **seguro de respaldo** (permite
   restaurar toda la VM si algo se corrompe), no el reset rutinario entre
   corridas — el reset de R3 se hace por `rental_id` en la propia BD (ver §5).

---

## 2. La matriz: qué se corre y cuántas veces

La tesis define **20 celdas** = 5 casos × 2 configuraciones × 2 motores
([`architecture.md`](architecture.md) §1). Una celda no es una corrida:

- **Cada celda se repite N≥5 veces** para estabilizar p50/p95
  ([`cases.md`](cases.md) §2, paso 6). Cada corrida en su propio archivo.
- **R1 barre concurrencia** `--threads={1,10,50,100}` ([`cases.md`](cases.md)
  §3): 4 sub-corridas × N cada una.
- **R2 / R5** usan hilos fijos (R2 ej. `--threads=10`, R5 `--threads=50`).
- **R3 / R4** no usan sysbench (procedure / queries single-shot envueltas en
  `time`); igual se repiten N≥5.

Volumen estimado por (motor × configuración), con N=5:

| Caso | Sub-corridas | Total con N=5 |
|---|---|---|
| R1 (barrido 4 hilos) | 4 | 20 |
| R2 (+ Q04 complementaria) | 2 | 10 |
| R3 | 1 | 5 |
| R4 (Q01 + Q02) | 2 | 10 |
| R5 | 1 | 5 |

≈ 50 corridas por (motor × config) × 4 combinaciones ≈ **200 corridas**. Si
el tiempo aprieta, bajar N a 3 en R1 (el que más multiplica) y mantener N=5
en R2/R5. **Documentar el N usado** en la bitácora.

---

## 3. Topología de sesiones

Dos sesiones, y lo importante es *dónde* corre cada una:

```
┌─ Sesión 1: CLIENTE (host o VM cliente) ───────────┐
│  Lanza sysbench y los clientes mariadb/psql       │
│  apuntando por red a la VM de BD (--host=<IP>)    │
└───────────────────────────────────────────────────┘
                       │  red
                       ▼
┌─ Sistema bajo prueba (SUT) = la VM de BD ──────────┐
│  Proceso mariadbd / postgres                       │
│  ┌─ Sesión 2: SSH dentro de ESTA VM ────────────┐  │
│  │  htop  → CPU/RAM/IO del servidor              │  │
│  │  (para C2: tail -f del log de auditoría)      │  │
│  └───────────────────────────────────────────────┘  │
└───────────────────────────────────────────────────┘
```

- **Sesión 1 (carga):** corre sysbench y las queries. **No correr sysbench
  dentro de la VM de BD** — le robaría CPU al motor y contaminaría la medición.
- **Sesión 2 (monitoreo):** SSH *dentro* de la VM de BD con `htop`.

> **htop es evidencia cualitativa/contextual, no métrica primaria.** Los
> números duros salen de sysbench y de los deltas de [`cases.md`](cases.md)
> §8. htop sirve para narrar saturación ("R5+C2 saturó CPU al ~95% vs ~70%
> en C1") y es más útil en R5. Basta capturarlo en una corrida representativa
> por celda, no en las ~300.

---

## 4. Orden recomendado

Cada VM es una sola configuración (C1 baseline o C2 plugin), así que no hay
triggers que cargar ni transiciones. Puedes iterar **por caso** (R1 en las 4
VMs, luego R2…) o **por VM** (todos los casos en una VM antes de pasar); el
dato sale igual. Las 4 VMs:

```
TUS-PostgreSQL        (C1)   TUS-PostgreSQL-Audit  (C2)
TUS-MariaDB           (C1)   TUS-MariaDB-Audit     (C2)
```

Dentro de cada VM, corre los casos de menos a más destructivo (minimiza
restauraciones de snapshot):

```
R1 → R2 → R4   (lecturas/escrituras leves: sin reset de datos entre ellos)
R3             (inserta filas: reset por rental_id entre corridas, ver §5)
R5             (carga sostenida: NO requiere reset — solo SELECT/UPDATE)
```

R3 inserta filas nuevas → entre corridas se revierten **por `rental_id`** (no
por fecha; la inflación abarca 2005–2037), ver [`cases.md`](cases.md) §5. R5
solo hace SELECT/UPDATE: los conteos no cambian, así que no requiere reset de
datos. Ninguno necesita restaurar snapshot como paso rutinario.

---

## 5. El loop por cada medición

Para cada (caso, motor, config), repetir N veces ([`cases.md`](cases.md) §2):

1. **Cache frío reproducible:** `sudo systemctl restart mariadb` /
   `postgresql`; esperar a que acepte conexiones ([`setup.md`](setup.md) §11).
2. **Reset de datos — solo R3:** revertir lo sembrado **por `rental_id`** (no
   por fecha), como en [`cases.md`](cases.md) §5. R5 no requiere reset (workload
   solo SELECT/UPDATE; conteos invariantes).
3. **Capturar estado inicial** (métricas de §6).
4. **Ejecutar el caso:** comando exacto en [`cases.md`](cases.md) §3–§7.
   (Corre `sysbench` desde la **raíz del repo**: las rutas a `benchmark-scripts/`
   son relativas, o usa la ruta absoluta al `.lua`.)
5. **Capturar estado final** (mismas métricas → el *delta* es el resultado
   de auditoría).
6. **Guardar:** `results/<R>_<config>_<motor>_runK.log` (carpeta local, está
   en `.gitignore`, no se versiona ni vive en las VMs).

---

## 6. Qué se captura ([`cases.md`](cases.md) §8)

| Métrica | Cuándo | Cómo |
|---|---|---|
| Throughput + latencia p50/p95 | siempre | output de sysbench; para R3/R4 usar `time` |
| Delta del log del plugin | **solo C2** | `wc -l` / `tail` del log antes y después → líneas nuevas = eventos auditados |
| Plan EXPLAIN | R4, ≥1 vez por config | `EXPLAIN FORMAT=JSON` / `EXPLAIN (ANALYZE, BUFFERS)` |
| htop (CPU/RAM) | opcional, 1 corrida representativa | screenshot de la Sesión 2 durante el pico |

El comparativo central de la tesis cruza el **costo en throughput/latencia**
de habilitar el plugin (C2) contra el baseline (C1), por motor — más el
**delta de eventos auditados** (líneas nuevas en el log del plugin).

> **Nota:** aun en R1 (solo lectura) el plugin puede añadir overhead, porque
> audita SELECTs cuando se configura con `server_audit_events=QUERY` /
> `pgaudit.log='all'` ([`cases.md`](cases.md) §3,
> [`architecture.md`](architecture.md) §5).

---

## 7. Punto de partida sugerido

Empezar por **TUS-PostgreSQL** (C1 baseline, sin plugin): es la celda más
simple (cero auditoría) y valida que el setup y la conectividad funcionan
antes de añadir el plugin. Secuencia inicial:

1. Verificar instalación/versiones y conectividad (§1).
2. Tomar el snapshot golden de TUS-PostgreSQL.
3. Correr R1 → R2 → R4 → R3 → R5, N≥5 cada uno (§4, §5).
4. Pasar a TUS-PostgreSQL-Audit (C2), luego a las VMs MariaDB.
