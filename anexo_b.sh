#!/bin/bash
# =============================================================================
# ANEXO B - Salidas de las pruebas de rendimiento
#
# TIENE DOS MODOS:
#
#  MODO 1 (recomendado) - mostrar resultados que YA guardaste:
#     bash anexo_b.sh
#     -> busca los .log de tus corridas (serie 2) y los junta en un archivo.
#        Estos son tus datos reales definitivos: es la mejor evidencia.
#
#  MODO 2 - re-ejecutar pruebas si ya no tienes los .log:
#     bash anexo_b.sh run MOTOR IP_DE_LA_VM
#     MOTOR = mariadb | postgres
#     Ej:  bash anexo_b.sh run mariadb 192.168.1.50
#     -> corre R1, R2, R3, R4, R5 (una corrida representativa) desde el CLIENTE
#        apuntando a la VM. OJO: R5 dura 10 min.
#     Debe ejecutarse desde la RAIZ del repo (donde esta benchmark-scripts/).
#
# Al terminar:  cat ~/anexo_b_resultado.txt   y capturas.
# =============================================================================
PW=alainez
MODE=${1:-display}

# ---------------------------------------------------------------------------
# MODO 1: BUSCAR Y MOSTRAR RESULTADOS EXISTENTES
# ---------------------------------------------------------------------------
if [ "$MODE" = display ]; then
    OUT=~/anexo_b_resultado.txt
    {
    echo "############################################################"
    echo "#  ANEXO B - RESULTADOS DE RENDIMIENTO (archivos guardados)"
    echo "#  Fecha: $(date)"
    echo "############################################################"
    echo

    FOUND=0
    for DIR in ~/results ./results ~/sakila-thesis-lab/results /root/results; do
        if [ -d "$DIR" ]; then
            LOGS=$(find "$DIR" -maxdepth 2 -name "*.log" 2>/dev/null | grep -v security | sort)
            if [ -n "$LOGS" ]; then
                echo ">>> Encontrados resultados en: $DIR"
                echo
                for f in $LOGS; do
                    echo "=========================================================="
                    echo "ARCHIVO: $f"
                    echo "=========================================================="
                    cat "$f"
                    echo
                    FOUND=1
                done
            fi
        fi
    done

    if [ "$FOUND" = 0 ]; then
        echo "!!! No se encontraron archivos .log de resultados guardados."
        echo "!!! Parece que no conservaste los .log de la serie 2."
        echo "!!!"
        echo "!!! Tienes que re-ejecutar. Corre, desde la raiz del repo:"
        echo "!!!     bash anexo_b.sh run mariadb  <IP_de_tu_VM_MariaDB>"
        echo "!!!     bash anexo_b.sh run postgres <IP_de_tu_VM_PostgreSQL>"
    fi
    echo
    echo "############################################################"
    echo "#  FIN ANEXO B (modo mostrar)"
    echo "############################################################"
    } 2>&1 | tee "$OUT"
    echo
    echo ">>> Guardado en: $OUT"
    echo ">>> Si aparecieron tus resultados: corre 'cat $OUT' y captura."
    echo ">>> Si NO habia nada: usa el modo run (ver mensaje de arriba)."
    exit 0
fi

# ---------------------------------------------------------------------------
# MODO 2: RE-EJECUTAR PRUEBAS REPRESENTATIVAS
# ---------------------------------------------------------------------------
if [ "$MODE" = run ]; then
    MOTOR=${2:?uso: bash anexo_b.sh run mariadb|postgres IP_VM}
    IP=${3:?falta la IP de la VM. Uso: bash anexo_b.sh run $MOTOR IP_VM}
    OUT=~/anexo_b_${MOTOR}_reejecucion.txt

    if [ ! -d benchmark-scripts ]; then
        echo "ERROR: no veo la carpeta benchmark-scripts/."
        echo "Debes correr esto desde la RAIZ del repo sakila-thesis-lab."
        echo "Haz:  cd ~/sakila-thesis-lab   (o donde tengas el repo)  y reintenta."
        exit 1
    fi

    if [ "$MOTOR" = mariadb ]; then
        LUA_RO=benchmark-scripts/oltp_read_only_sakila.lua
        LUA_RW=benchmark-scripts/oltp_read_write_sakila.lua
        DRV="--db-driver=mysql --mysql-host=$IP --mysql-port=3306 --mysql-user=thesis --mysql-password=$PW --mysql-db=sakila"
        QDIR=mysql-sakila-db/queries
        SHOT()  { time mariadb -h $IP -u thesis -p$PW sakila -e "$1" 2>&1; }
        SHOTF() { time mariadb -h $IP -u thesis -p$PW sakila < "$1" 2>&1; }
    else
        LUA_RO=benchmark-scripts/oltp_read_only_sakila.lua
        LUA_RW=benchmark-scripts/oltp_read_write_sakila.lua
        DRV="--db-driver=pgsql --pgsql-host=$IP --pgsql-port=5432 --pgsql-user=thesis --pgsql-password=$PW --pgsql-db=pagila"
        QDIR=postgres-sakila-db/queries
        SHOT()  { time env PGPASSWORD=$PW psql -h $IP -U thesis -d pagila -c "$1" 2>&1; }
        SHOTF() { time env PGPASSWORD=$PW psql -h $IP -U thesis -d pagila -f "$1" 2>&1; }
    fi

    {
    echo "############################################################"
    echo "#  ANEXO B - RE-EJECUCION DE PRUEBAS (representativa)"
    echo "#  Motor: $MOTOR   VM: $IP   Fecha: $(date)"
    echo "#  NOTA: numeros pueden variar levemente vs serie 2 (normal)."
    echo "############################################################"
    echo

    echo "########## R1 - OLTP solo lectura (barrido de concurrencia) ##########"
    for T in 1 10 50 100; do
        echo "----- R1 con $T hilos (60s) -----"
        sysbench $LUA_RO $DRV --threads=$T --time=60 --report-interval=20 run 2>&1
        echo
    done

    echo "########## R2 - OLTP mixto 80/20 (10 hilos, 60s) ##########"
    sysbench $LUA_RW $DRV --threads=10 --time=60 --report-interval=20 run 2>&1
    echo

    echo "########## R3 - Insercion masiva (procedure, cronometrado) ##########"
    echo "(inserta ~6000 rentals + 6000 payments; si te importa el conteo exacto,"
    echo " restaura snapshot despues)"
    SHOT "CALL sp_seed_synthetic_data(0, 30, 200);"
    echo

    echo "########## R4 - Consultas analiticas (Q01 rapida, Q02 pesada) ##########"
    echo "----- Q01 Analytics_RAM (tiempo) -----"
    SHOTF "$QDIR/01_Analytics_RAM.sql"
    echo
    echo "----- Q02 Subqueries_CPU (tiempo) -----"
    SHOTF "$QDIR/02_Subqueries_CPU.sql"
    echo

    echo "########## R5 - Carga sostenida 10 min (50 hilos) ##########"
    echo "(esto tarda 10 minutos; puedes abrir otra sesion SSH en la VM con htop"
    echo " para capturar el pico de CPU)"
    sysbench $LUA_RW $DRV --threads=50 --time=600 --report-interval=60 run 2>&1
    echo

    echo "############################################################"
    echo "#  FIN ANEXO B (re-ejecucion) - $MOTOR"
    echo "############################################################"
    } 2>&1 | tee "$OUT"
    echo
    echo ">>> Guardado en: $OUT"
    echo ">>> Corre 'cat $OUT' y captura por secciones."
    exit 0
fi

echo "Modo no reconocido. Usa:  bash anexo_b.sh    (mostrar)"
echo "                    o:  bash anexo_b.sh run MOTOR IP_VM   (re-ejecutar)"
