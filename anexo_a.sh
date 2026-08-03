#!/bin/bash
# =============================================================================
# ANEXO A - Configuracion del entorno
# Uso:   bash anexo_a.sh MOTOR CONFIG
#        MOTOR = mariadb | postgres     CONFIG = C1 | C2
# Ej:    bash anexo_a.sh mariadb C2
# Se ejecuta DENTRO de cada VM (por SSH o consola).
# Al terminar:  cat ~/anexo_a_<motor>_<config>.txt   y capturas eso.
# =============================================================================
MOTOR=${1:?uso: bash anexo_a.sh mariadb|postgres C1|C2}
CONFIG=${2:?uso: bash anexo_a.sh mariadb|postgres C1|C2}
PW=alainez
OUT=~/anexo_a_${MOTOR}_${CONFIG}.txt

{
echo "############################################################"
echo "#  ANEXO A - CONFIGURACION DEL ENTORNO"
echo "#  Motor: $MOTOR   Config: $CONFIG"
echo "#  Host VM: $(hostname)   Fecha: $(date)"
echo "############################################################"
echo

echo "===== A1. Version del sistema operativo ====="
lsb_release -d 2>/dev/null || cat /etc/os-release | grep PRETTY
echo

if [ "$MOTOR" = mariadb ]; then
    echo "===== A1. Version de MariaDB ====="
    mariadb --version
    echo
    echo "===== A2/A3. Plugin de auditoria server_audit (vacio en C1, activo en C2) ====="
    echo $PW | sudo -S mariadb -e "SHOW VARIABLES LIKE 'server_audit%';" 2>/dev/null
    echo
    echo "===== A4. Conteo de filas tras inflacion (debe dar rental=513408, payment=513568) ====="
    echo $PW | sudo -S mariadb sakila -e "SELECT COUNT(*) AS rental FROM rental;" 2>/dev/null
    echo $PW | sudo -S mariadb sakila -e "SELECT COUNT(*) AS payment FROM payment;" 2>/dev/null
    echo
    echo "===== A-extra. Triggers de auditoria instalados en sakila ====="
    echo $PW | sudo -S mariadb sakila -e "SELECT TRIGGER_NAME FROM information_schema.TRIGGERS WHERE TRIGGER_SCHEMA='sakila';" 2>/dev/null
else
    echo "===== A1. Version de PostgreSQL ====="
    psql --version
    echo
    echo "===== A2. shared_preload_libraries (debe incluir pgaudit en C2) ====="
    echo $PW | sudo -S -u postgres psql -c "SHOW shared_preload_libraries;" 2>/dev/null
    echo
    echo "===== A2/A3. Extension pgAudit y su configuracion ====="
    echo $PW | sudo -S -u postgres psql -d pagila -c "SELECT extname, extversion FROM pg_extension WHERE extname='pgaudit';" 2>/dev/null
    echo $PW | sudo -S -u postgres psql -c "SHOW pgaudit.log;" 2>/dev/null
    echo $PW | sudo -S -u postgres psql -c "SHOW log_statement;" 2>/dev/null
    echo
    echo "===== A4. Conteo de filas tras inflacion (debe dar rental=513408, payment=513568) ====="
    echo $PW | sudo -S -u postgres psql -d pagila -c "SELECT COUNT(*) AS rental FROM rental;" 2>/dev/null
    echo $PW | sudo -S -u postgres psql -d pagila -c "SELECT COUNT(*) AS payment FROM payment;" 2>/dev/null
    echo
    echo "===== A-extra. Triggers de auditoria instalados en pagila ====="
    echo $PW | sudo -S -u postgres psql -d pagila -c "SELECT tgname FROM pg_trigger WHERE NOT tgisinternal AND tgname LIKE 'trg_audit%';" 2>/dev/null
fi

echo
echo "############################################################"
echo "#  FIN ANEXO A - $MOTOR $CONFIG"
echo "############################################################"
} 2>&1 | tee "$OUT"

echo
echo ">>> Guardado en: $OUT"
echo ">>> Ahora corre:  cat $OUT   y captura la pantalla."
