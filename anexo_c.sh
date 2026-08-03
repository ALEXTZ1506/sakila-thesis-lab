#!/bin/bash
# =============================================================================
# ANEXO C - Fragmentos de logs de auditoria
# Uso:   bash anexo_c.sh MOTOR
#        MOTOR = mariadb | postgres
# Ej:    bash anexo_c.sh mariadb
# Se ejecuta DENTRO de la VM -Audit (C2), DESPUES de haber corrido alguna
# prueba (Anexo B o D) para que el log tenga eventos.
# Al terminar:  cat ~/anexo_c_<motor>.txt   y capturas.
# =============================================================================
MOTOR=${1:?uso: bash anexo_c.sh mariadb|postgres}
PW=alainez
OUT=~/anexo_c_${MOTOR}.txt

if [ "$MOTOR" = mariadb ]; then
    LOG=/var/log/mariadb/server_audit.log
else
    LOG=/var/log/postgresql/postgresql-16-main.log
fi

{
echo "############################################################"
echo "#  ANEXO C - LOG DE AUDITORIA ($MOTOR)"
echo "#  Archivo: $LOG"
echo "#  Fecha: $(date)"
echo "############################################################"
echo

echo "===== C1. Tamano fisico del log ====="
echo $PW | sudo -S ls -lh "$LOG" 2>/dev/null
echo

echo "===== C2. Total de lineas / eventos registrados ====="
if [ "$MOTOR" = mariadb ]; then
    echo "Total de lineas en server_audit.log:"
    echo $PW | sudo -S wc -l "$LOG" 2>/dev/null
else
    echo "Total de eventos AUDIT registrados por pgAudit:"
    echo $PW | sudo -S grep -c 'AUDIT:' "$LOG" 2>/dev/null
fi
echo

echo "===== C3. Fragmento representativo (ultimas 20 lineas de auditoria) ====="
if [ "$MOTOR" = mariadb ]; then
    echo "(estructura: timestamp,host,usuario,conexion,operacion,base,objeto,sentencia,retorno)"
    echo
    echo $PW | sudo -S tail -n 20 "$LOG" 2>/dev/null
else
    echo "(lineas con prefijo AUDIT: clase de evento, sentencia, objeto)"
    echo
    echo $PW | sudo -S grep 'AUDIT:' "$LOG" 2>/dev/null | tail -n 20
fi
echo

echo "############################################################"
echo "#  FIN ANEXO C - $MOTOR"
echo "############################################################"
} 2>&1 | tee "$OUT"

echo
echo ">>> Guardado en: $OUT"
echo ">>> Corre 'cat $OUT' y captura."
