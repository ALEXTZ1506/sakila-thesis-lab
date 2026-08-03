# Scripts de evidencia para los anexos (A–D)

Este documento explica cómo usar los 5 scripts de la raíz del repo
(`anexo_a.sh`, `anexo_b.sh`, `anexo_c.sh`, `anexo_d.sh`, `correr_todo_vm.sh`)
que generan la evidencia de los anexos de la tesis (configuración,
rendimiento, logs de auditoría y seguridad). Complementa a
[`runbook.md`](runbook.md), [`cases.md`](cases.md) y
[`security-cases.md`](security-cases.md), que documentan el diseño de cada
caso; este documento solo cubre **cómo correr los scripts que empaquetan
la evidencia** para pegarla en el documento de tesis.

> Los scripts se corren manualmente (por PuTTY o desde el cliente), **no**
> forman parte del pipeline de medición en sí. No los ejecutes contra una
> VM en medio de una corrida real (contaminarías el log que estás midiendo).

---

## 1. Qué hace cada script

| Script | Dónde se corre | Qué genera |
|---|---|---|
| `anexo_a.sh MOTOR CONFIG` | Dentro de cada VM | Versión de SO/motor, estado del plugin de auditoría, conteo de filas (513k) |
| `anexo_d.sh CONFIG MOTOR` | Dentro de cada VM, raíz del repo | Corre `security/run_security.sh` (S1–S5) y junta los deltas de log por caso |
| `anexo_c.sh MOTOR` | Dentro de cada VM `-Audit` (C2) | Fragmento y tamaño del log de auditoría, después de que ya tenga eventos |
| `correr_todo_vm.sh MOTOR CONFIG` | Dentro de cada VM, raíz del repo | Envoltorio: corre A → D → C (C solo si `CONFIG=C2`) en una sola línea |
| `anexo_b.sh` / `anexo_b.sh run MOTOR IP` | Desde el CLIENTE | Muestra los `.log` de rendimiento ya guardados, o re-ejecuta una corrida representativa (R1–R5) |

`MOTOR` = `mariadb` \| `postgres`. `CONFIG` = `C1` (baseline) \| `C2` (con
plugin).

---

## 2. Uso dentro de cada VM (por PuTTY)

Desde la raíz del repo, en cada una de las 4 VMs:

```bash
cd ~/sakila-thesis-lab
git pull
bash correr_todo_vm.sh <motor> <config>
```

Ejemplos concretos por VM:

```bash
bash correr_todo_vm.sh mariadb  C1     # TUS-MariaDB
bash correr_todo_vm.sh mariadb  C2     # TUS-MariaDB-Audit
bash correr_todo_vm.sh postgres C1     # TUS-PostgreSQL
bash correr_todo_vm.sh postgres C2     # TUS-PostgreSQL-Audit
```

Esto corre, en orden: **Anexo A** (configuración) → **Anexo D** (S1–S5) →
**Anexo C** (fragmento de log, solo si `CONFIG=C2`; en C1 no hay log de
plugin que mostrar). Los tres pasos también se pueden invocar por separado
con `anexo_a.sh`, `anexo_d.sh` y `anexo_c.sh` si solo necesitas rehacer uno.

### Dejarlo corriendo sin supervisión

`anexo_d.sh` (S1–S5) no debería tardar mucho, pero si vas a dejar cualquiera
de estos scripts corriendo y cerrar PuTTY, la sesión SSH se cuelga con la
ventana y el proceso **se detiene a medias**. Dos formas de evitarlo:

**Opción `tmux` (recomendada):**

```bash
tmux new -s tesis
bash correr_todo_vm.sh mariadb C2
# Ctrl-b, luego d   -> te desconectas, el proceso sigue corriendo
# para volver luego:
tmux attach -t tesis
```

**Opción `nohup`:**

```bash
nohup bash correr_todo_vm.sh mariadb C2 > ~/master_salida.log 2>&1 &
# puedes cerrar PuTTY; al volver:
cat ~/master_salida.log
```

Con `tmux` puedes ver la salida en vivo al reconectar; con `nohup` solo
queda en el archivo de log. Cualquiera de las dos sirve, `tmux` es más
cómodo si quieres ir mirando el progreso.

---

## 3. Uso desde el CLIENTE (Anexo B — rendimiento)

`anexo_b.sh` **no** se corre dentro de las VMs de base de datos, sino desde
la máquina cliente (la misma desde donde lanzas sysbench en el runbook),
en la raíz del repo:

```bash
# Modo 1 (recomendado): mostrar los .log que ya guardaste en results/
bash anexo_b.sh

# Modo 2: re-ejecutar una corrida representativa (R1-R5) si no conservaste los .log
bash anexo_b.sh run <motor> <IP_de_la_VM>
# Ej: bash anexo_b.sh run postgres 192.168.1.93
```

El modo 2 tarda más porque incluye R5 (carga sostenida de 10 minutos).

---

## 4. Credenciales y archivos de salida

- La contraseña usada en todos los scripts es la ya configurada para el rol
  `thesis` en las 4 VMs (la misma que usan `security/run_security.sh` y los
  ejemplos de [`setup.md`](setup.md)).
- Cada script deja su salida en el `HOME` del usuario que lo corrió, como
  `~/anexo_a_<motor>_<config>.txt`, `~/anexo_c_<motor>.txt`,
  `~/anexo_d_<config>_<motor>.txt` y `~/anexo_b_resultado.txt` (o
  `~/anexo_b_<motor>_reejecucion.txt` en modo `run`).
- Para capturar: `cat ~/anexo_XXX.txt` y pantallazo del resultado completo.

---

## 5. Orden sugerido

1. **Anexo A** en las 4 VMs (rápido, son consultas de estado).
2. **Anexo D** en las 4 VMs (corre `security/run_security.sh`; el contraste
   C1 casi vacío vs C2 con eventos es el hallazgo central de esa fase).
3. **Anexo C** en las 2 VMs `-Audit` (sale "gratis" tras correr D, el log ya
   tiene eventos que mostrar).
4. **Anexo B** desde el cliente (el más largo si re-ejecutas; instantáneo
   si ya tienes los `.log` de la serie 2 en `results/`).

Los pasos 1–3 quedan cubiertos en una sola línea con `correr_todo_vm.sh`.
