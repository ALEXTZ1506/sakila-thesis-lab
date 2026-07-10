#!/bin/bash
# =============================================================================
# run_security.sh CONFIG MOTOR   (CONFIG=C1|C2, MOTOR=postgres|mariadb)
# Ejecuta S1-S5 a nivel BD y captura el delta del log de auditoria por caso.
# S4 no-destructivo: PG via BEGIN/ROLLBACK; MariaDB via objetos desechables.
# Evidencia -> ~/results/security/S<n>_<CONFIG>_<MOTOR>.log
# =============================================================================
set -u
CONFIG=${1:?uso: run_security.sh C1|C2 postgres|mariadb}
MOTOR=${2:?}
PW=alainez
OUT=~/results/security
mkdir -p "$OUT"

if [ "$MOTOR" = postgres ]; then
  LOG=/var/log/postgresql/postgresql-16-main.log
  Q()     { PGPASSWORD=$PW psql -h 127.0.0.1 -U thesis -d pagila -v ON_ERROR_STOP=0 -c "$1" 2>&1; }
  QSUPER(){ echo $PW | sudo -S -u postgres psql -d pagila -v ON_ERROR_STOP=0 -c "$1" 2>&1; }
  QBAD()  { PGPASSWORD="bad_$1" psql -h 127.0.0.1 -U thesis -d pagila -c "SELECT 1" 2>&1; }
  QLOW()  { PGPASSWORD=lowpass psql -h 127.0.0.1 -U lowpriv -d pagila -c "$1" 2>&1; }
else
  if [ "$CONFIG" = C2 ]; then LOG=/var/log/mariadb/server_audit.log; else LOG=/var/log/mysql/error.log; fi
  Q()     { mariadb -u thesis -p$PW sakila -e "$1" 2>&1; }
  QSUPER(){ echo $PW | sudo -S mariadb -e "$1" 2>&1; }
  QBAD()  { mariadb -u thesis -pbad_$1 -e "SELECT 1" 2>&1; }
  QLOW()  { mariadb -u lowpriv -plowpass sakila -e "$1" 2>&1; }
fi

# Patron que funciona en plink: 'echo pw | sudo -S CMD ARCHIVO' (archivo como
# argumento, NUNCA por redireccion '<', que roba el stdin del password).
logoff() { echo $PW | sudo -S stat -c %s "$LOG" 2>/dev/null || echo 0; }
snap()   { # $1=Scase $2=offset ; guarda SOLO el delta del log de ese caso
  local name=$1 off=$2
  echo $PW | sudo -S tail -c +$((off+1)) "$LOG" 2>/dev/null > "$OUT/${name}_${CONFIG}_${MOTOR}.log"
  echo "  [$name] lineas nuevas en log: $(wc -l < "$OUT/${name}_${CONFIG}_${MOTOR}.log")"
}

echo "=================== SEGURIDAD $CONFIG / $MOTOR ==================="
echo "log de auditoria: $LOG"
# Truncar el log una vez al inicio para offsets limpios (no destruye datos).
echo $PW | sudo -S truncate -s 0 "$LOG" 2>/dev/null && echo "log truncado (arranque limpio)"

# ---------- S1: Inyeccion SQL ----------
O=$(logoff)
Q "SELECT staff_id, username FROM staff WHERE username='Mike' AND password='' OR '1'='1';" >/dev/null
if [ "$MOTOR" = postgres ]; then
  Q "SELECT first_name, last_name FROM customer WHERE customer_id=1 UNION SELECT username, password FROM staff;" >/dev/null
else
  Q "SELECT first_name, last_name FROM customer WHERE customer_id=1 UNION SELECT username, password FROM staff;" >/dev/null
fi
echo "S1 inyeccion ejecutada"; snap S1 "$O"

# ---------- S2: Fuerza bruta de autenticacion ----------
O=$(logoff)
for i in $(seq 1 20); do QBAD "$i" >/dev/null 2>&1; done
echo "S2 fuerza bruta: 20 intentos fallidos"; snap S2 "$O"

# ---------- S3: Escalada de privilegios ----------
if [ "$MOTOR" = postgres ]; then
  QSUPER "DROP ROLE IF EXISTS lowpriv; CREATE ROLE lowpriv LOGIN PASSWORD 'lowpass'; GRANT CONNECT ON DATABASE pagila TO lowpriv; GRANT SELECT ON film TO lowpriv;" >/dev/null
else
  QSUPER "DROP USER IF EXISTS lowpriv; CREATE USER lowpriv IDENTIFIED BY 'lowpass'; GRANT SELECT ON sakila.film TO lowpriv;" >/dev/null
fi
O=$(logoff)
QLOW "SELECT * FROM staff;" >/dev/null 2>&1          # tabla fuera de su alcance
if [ "$MOTOR" = postgres ]; then
  QLOW "GRANT ALL PRIVILEGES ON DATABASE pagila TO lowpriv;" >/dev/null 2>&1
else
  QLOW "GRANT ALL PRIVILEGES ON sakila.* TO lowpriv;" >/dev/null 2>&1
fi
echo "S3 escalada ejecutada"; snap S3 "$O"
if [ "$MOTOR" = postgres ]; then QSUPER "DROP OWNED BY lowpriv; DROP ROLE lowpriv;" >/dev/null; else QSUPER "DROP USER lowpriv;" >/dev/null; fi

# ---------- S5: Exfiltracion (antes de S4 por destructividad) ----------
O=$(logoff)
Q "SELECT * FROM customer;" >/dev/null
Q "SELECT email FROM customer;" >/dev/null
echo "S5 exfiltracion ejecutada"; snap S5 "$O"

# ---------- S4: DDL malicioso (NO destructivo) ----------
O=$(logoff)
if [ "$MOTOR" = postgres ]; then
  Q "BEGIN; DROP TABLE payment; ROLLBACK;" >/dev/null          # DROP auditado, tabla sobrevive
  QSUPER "CREATE USER attacker PASSWORD 'backdoor';" >/dev/null
  QSUPER "DROP USER attacker;" >/dev/null
else
  Q "CREATE TABLE payment_stolen AS SELECT * FROM payment LIMIT 5; DROP TABLE payment_stolen;" >/dev/null
  QSUPER "CREATE USER attacker IDENTIFIED BY 'backdoor';" >/dev/null
  QSUPER "DROP USER attacker;" >/dev/null
fi
echo "S4 DDL malicioso ejecutado (no destructivo)"; snap S4 "$O"

echo "=================== FIN $CONFIG / $MOTOR ==================="
