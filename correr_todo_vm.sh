#!/bin/bash
# =========================================================================
# correr_todo_vm.sh  MOTOR  CONFIG     (MOTOR=mariadb|postgres, CONFIG=C1|C2)
#
# Ejecuta EN ESTA VM los anexos que corren localmente, en orden:
#   Anexo A (configuracion) -> Anexo D (seguridad) -> Anexo C (log, solo C2)
#
# NO incluye el Anexo B (rendimiento/sysbench): eso se corre desde el CLIENTE
# con anexo_b.sh (ver guia). Aqui van solo las partes que necesitan estar
# dentro de la VM (acceso local a los logs y a run_security.sh).
#
# --- USO BASICO (una linea por VM) ---
#   cd ~/sakila-thesis-lab        # o donde tengas el repo
#   git pull                      # trae los scripts si los subiste con Claude Code
#   bash correr_todo_vm.sh mariadb C2
#
# --- PARA CORRER Y DORMIR (sobrevive si cierras PuTTY) ---
# Opcion tmux (recomendada):
#   tmux new -s tesis
#   bash correr_todo_vm.sh mariadb C2
#   # Ctrl-b y luego d  -> te desconectas, sigue corriendo
#   # para volver:  tmux attach -t tesis
#
# Opcion nohup:
#   nohup bash correr_todo_vm.sh mariadb C2 > ~/master_salida.log 2>&1 &
#   # puedes cerrar PuTTY; al volver:  cat ~/master_salida.log
#
# Si NO usas tmux/nohup y cierras PuTTY, el proceso se DETIENE. Por eso,
# para dejarlo corriendo mientras duermes, usa tmux o nohup si o si.
# =========================================================================
MOTOR=${1:?uso: bash correr_todo_vm.sh mariadb|postgres C1|C2}
CONFIG=${2:?uso: bash correr_todo_vm.sh mariadb|postgres C1|C2}

# Situarse en la raiz del repo (para que security/ y rutas relativas funcionen)
ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"
if [ -n "$ROOT" ]; then
    cd "$ROOT"
elif [ -d ~/sakila-thesis-lab ]; then
    cd ~/sakila-thesis-lab
else
    echo "ERROR: no encuentro el repo. Ve a la carpeta del repo y reintenta."
    exit 1
fi

echo "############################################################"
echo "#  MASTER VM - Motor: $MOTOR   Config: $CONFIG"
echo "#  Repo: $(pwd)"
echo "#  Host: $(hostname)   Fecha: $(date)"
echo "############################################################"

echo; echo ">>> [1/3] ANEXO A (configuracion del entorno)"
bash anexo_a.sh "$MOTOR" "$CONFIG"

echo; echo ">>> [2/3] ANEXO D (pruebas de seguridad S1-S5)"
bash anexo_d.sh "$CONFIG" "$MOTOR"

if [ "$CONFIG" = C2 ]; then
    echo; echo ">>> [3/3] ANEXO C (fragmento del log de auditoria)"
    bash anexo_c.sh "$MOTOR"
else
    echo; echo ">>> [3/3] ANEXO C omitido: C1 (baseline) no tiene log del plugin"
fi

echo
echo "############################################################"
echo "#  MASTER TERMINADO. Archivos generados en tu HOME:"
ls -la ~/anexo_*.txt 2>/dev/null
echo "#"
echo "#  En la manana: por cada archivo haz  'cat ~/anexo_XXX.txt'  y captura."
echo "############################################################"
