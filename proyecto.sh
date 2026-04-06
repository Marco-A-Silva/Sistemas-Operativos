#!/bin/bash

sudo /usr/bin/updatedb --prunepaths "*/tmp */var/spool */media */mnt */.cache */.cargo */.rustup */snap" 

advFind() {
    local FECHA_REGEX='^[0-9]{4}-(0|1)[0-9]-[0-9]{1,2}$'
    local fechas=()
    local texto=()

    for param in "$@"; do
        
        [[ "$param" =~ $FECHA_REGEX ]] && fechas+=("$param") || texto+=("$param")
        
    done
    
    if [[ ${#fechas[@]} -eq 0 && ${#texto[@]} -eq 0 ]]; then
        locate -r "/home/$USER/.*"

    elif [[ ${#fechas[@]} -eq 2 ]]; then
        if [[ ${#texto[@]} -gt 0 ]]; then
            find "/home/$USER" -regextype egrep -newermt "${fechas[0]}" ! -newermt "${fechas[1]} 23:59:59" -regex "/home/$USER/${texto[0]}" \
            -not -path "*/.cache/*" \
            -not -path "*/.var/*" \
            -not -path "*/snap/*" \
            -not -path "*/.rustup/*" \
            -not -path "*/.cargo/*"
        else
            find "/home/$USER" -newermt "${fechas[0]}" ! -newermt "${fechas[1]}" \
                -not -path "*/.cache/*" \
                -not -path "*/.var/*" \
                -not -path "*/snap/*" \
                -not -path "*/.rustup/*" \
                -not -path "*/.cargo/*"
        fi
    elif [[ ${#fechas[@]} -eq 1 ]]; then
        if [[ ${#texto[@]} -gt 0 ]]; then
            find "/home/$USER" -regextype egrep -newermt "${fechas[0]}" ! -newermt "${fechas[0]} 23:59:59" -regex "/home/$USER/${texto[0]}" \
                -not -path "*/.cache/*" \
                -not -path "*/.var/*" \
                -not -path "*/snap/*" \
                -not -path "*/.rustup/*" \
                -not -path "*/.cargo/*"
        else
            find "/home/$USER" -newermt "${fechas[0]}" ! -newermt "${fechas[0]} 23:59:59" \
                -not -path "*/.cache/*" \
                -not -path "*/.var/*" \
                -not -path "*/snap/*" \
                -not -path "*/.rustup/*" \
                -not -path "*/.cargo/*"
        fi
    else

        for nombre in "${texto[@]}"; do
            locate -r "/home/$USER/$texto"
        done
    fi

}

contFind() {
    grep -P -r -i -l $1 "$HOME" \
        --exclude-dir=.cache \
        --exclude-dir=.var \
        --exclude-dir=snap \
        --exclude-dir=.rustup \
        --exclude-dir=.cargo \
        2>/dev/null
}

normFind() {
    local pattern=${1:-".*"}
    egrep -R -i "^Name=$pattern" \
        /usr/share/applications/ \
        ~/.local/share/applications/ \
        /var/lib/flatpak/exports/share/applications/ \
        /var/lib/snapd/desktop/applications/ \
        2>/dev/null | cut -d: -f1 | sort -u | while read f; do 
            name=$(grep "^Name=" "$f" | head -1 | cut -d= -f2) 
            desktop=$( basename "$f" .desktop ) 
            echo "$name ($desktop)" 
        done
}

while true; do

echo -e "Elige un modo \nOpciones: [Apps]-[Archivos]-[Contenido]-[Procesos]-[Encriptar]-[Desencriptar]-[Backup]-[LoadBackup]-[Exit]"
read modo

if [[ ! "$modo" =~ ^(Apps|Archivos|Contenido|Procesos|Encriptar|Desencriptar|Backup|LoadBackUp|Exit)$ ]]; then
    echo -e "El modo elegido es invalido, por favor elegir un modo valido\n"
    sleep 0.5
    continue
fi

[ "$modo" =  Exit ] && break

echo Parametros de busqueda:
read -a prompt

case $modo in

    Apps)
        results=$( normFind "${prompt[@]}" )
    ;;
    Archivos)
        results=$( advFind "${prompt[@]}" )
    ;;
    Contenido)
        results=$( contFind "${prompt[@]}" )
    ;;
    Procesos)
        if [ -z "${prompt[@]}" ]; then
            results=$( ps au )
        else
            results=$( ps u -C "${prompt[@]}" )
        fi
    ;;
    Encriptar)
        results=$( advFind "${prompt[@]}" )
        for result in $results;
        do
            gzip $result

        done
    ;;
    Desencriptar)
        results=$( advFind "${prompt[@]}" )
        for result in $results;
        do
           gunzip $result
        done
    ;;
    Backup)
        results=$( advFind ""${prompt[@]}"" )
        tar -czf $HOME/crypt.tar.gz $results
    ;;
    LoadBackUp)
        results=$(advFind ""${prompt[@]}"".tar.gz)
        for result in $results;
        do
            tar -xvzf "$result" -C $HOME --strip-components=2
        done
    ;;

esac

if [ -z "$results" ]; then
    echo No Results

else

    if [ $modo = Backup ]; then
    
        printf "\nSe hizo un backup el %s %s\n" "$(date +%H:%M:%S)" "$(date +%d/%m/%Y)"

    elif [ $modo = LoadBckUp ]; then

        printf '%s\n' "Se cargo el backup"

    else

        echo -e "------------------------------RESULTADOS------------------------------\n"
        printf '%s\n' "$results"
        echo -e "\n---------------------------------------------------------------------\n"
    fi

    [ $modo = Procesos ] && act="frenar" || act="abrir"
    echo "Desea $act alguno de los resultados de busqueda?(Y/n)"
    read option
    while [[ $option != n ]]; do
        if [ "$option" = Y ] || [ "$option" = y ]; then
            if [ $modo = Backup ]; then
                echo "(y/n)"
                read action
                if [ $action = y ]; then
                    vim $HOME/crypt.tar.gz
                fi
                exit
    
            elif [ $modo = Apps ]; then
    
                echo "Elegir una app"
                read app
                gtk-launch "$app" &
                exit
            
            elif [ $modo = Procesos ];then

                echo "Elegir el proceso (PID)"
                read PID
                kill $PID

            else
    
                echo "Elegir un resultado:"
                read resultado
                vim $resultado
                exit
            fi
        
        else
            
            echo "Por favor elegir una opcion correspondiente"
            read option

        fi
    done
fi

done
