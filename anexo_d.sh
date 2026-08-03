#!/bin/bash
# =============================================================================
# ANEXO D - Evidencia de las pruebas de seguridad (S1-S5)
# Uso:   bash anexo_d.sh CONFIG MOTOR
#        CONFIG = C1 | C2     MOTOR = mariadb | postgres
# Ej:    bash anexo_d.sh C2 mariadb
#
# Envuelve tu script security/run_security.sh (que YA existe): ejecuta los 5
# ataques, y luego junta los deltas de log de cada caso en un solo archivo.
# Se ejecuta DENTRO de la VM, desde la RAIZ del repo (donde esta security/).
#
# Corre las 4 combinaciones (una por VM):
#     bash anexo_d.sh C1 mariadb     (en TUS-MariaDB)
#     bash anexo_d.sh C2 mariadb     (en TUS-MariaDB-Audit)
#     bash anexo_d.sh C1 postgres    (en TUS-PostgreSQL)
#     bash anexo_d.sh C2 postgres    (en TUS-PostgreSQL-Audit)
#
# Al terminar:  cat ~/anexo_d_<config>_<motor>.txt   y capturas.
# El hallazgo clave se ve comparando C1 (casi vacio) vs C2 (lleno) del mismo caso.
# =============================================================================
CONFIG=${1:?uso: bash anexo_d.sh C1|C2 mariadb|postgres}
MOTOR=${2:?uso: bash anexo_d.sh C1|C2 mariadb|postgres}
OUT=~/anexo_d_${CONFIG}_${MOTOR}.txt

# Situarse en la raiz del repo (para que security/run_security.sh se encuentre
# sin importar desde que directorio se invoco este script).
ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"
if [ -n "$ROOT" ]; then
    cd "$ROOT"
elif [ -d ~/sakila-thesis-lab ]; then
    cd ~/sakila-thesis-lab
fi

if [ ! -f security/run_security.sh ]; then
    echo "ERROR: no encuentro security/run_security.sh"
    echo "Debes correr esto desde la RAIZ del repo sakila-thesis-lab."
    echo "Haz:  cd ~/sakila-thesis-lab   y reintenta."
    exit 1
fi

{
echo "############################################################"
echo "#  ANEXO D - PRUEBAS DE SEGURIDAD S1-S5"
echo "#  Config: $CONFIG   Motor: $MOTOR"
echo "#  Host VM: $(hostname)   Fecha: $(date)"
echo "############################################################"
echo

echo "########## Ejecucion de la bateria de ataques ##########"
bash security/run_security.sh "$CONFIG" "$MOTOR"
echo

echo "########## Deltas de log capturados por cada ataque ##########"
echo "(cada bloque = lo que el registro de auditoria capturo tras ese ataque)"
echo
SECDIR=~/results/security
for S in S1 S2 S3 S4 S5; do
    F="$SECDIR/${S}_${CONFIG}_${MOTOR}.log"
    echo "=========================================================="
    echo "  $S  (config $CONFIG, motor $MOTOR)"
    echo "=========================================================="
    if [ -f "$F" ]; then
        LINES=$(wc -l < "$F")
        echo "  Lineas capturadas en el log: $LINES"
        echo "  ---- contenido del delta ----"
        cat "$F"
    else
        echo "  (sin archivo de delta; el ataque no genero registro)"
    fi
    echo
done

echo "############################################################"
echo "#  FIN ANEXO D - $CONFIG $MOTOR"
echo "#"
echo "#  RECORDATORIO: el hallazgo central es el contraste."
echo "#  Compara este archivo (C1) contra el de C2 del mismo motor:"
echo "#  en C1 los ataques casi no dejan rastro (lineas ~0), en C2 si."
echo "############################################################"
} 2>&1 | tee "$OUT"

echo
echo ">>> Guardado en: $OUT"
echo ">>> Corre 'cat $OUT' y captura."
