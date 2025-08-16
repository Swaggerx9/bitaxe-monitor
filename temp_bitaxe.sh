#!/bin/bash

# Cargar archivo de configuración
CONFIG_FILE="./bitaxe.conf"
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Error: No se encontró el archivo de configuración $CONFIG_FILE" >> ./bitaxe.log
    exit 1
fi

# Variable para almacenar el tiempo de la última alerta
ultimo_aviso=0

# Función para enviar un aviso a Telegram
enviar_aviso() {
    local mensaje="$1"
    local prioridad="$2"
    local priority_text
    if [ "$prioridad" -eq 8 ]; then
        priority_text="[ALTA PRIORIDAD] "
    else
        priority_text="[Normal] "
    fi
    local response
    response=$(curl -s -w "%{http_code}" -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
        -H "Content-Type: application/json" \
        -d "{\"chat_id\": \"$TELEGRAM_CHAT_ID\", \"text\": \"$priority_text$mensaje\"}" -o /dev/null)
    if [ "$response" != "200" ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Error al enviar notificación a Telegram: HTTP $response" >> ./bitaxe.log
    fi
}

# Función para obtener la temperatura de Bitaxe
obtener_temperatura_bitaxe() {
    if ! ping -c 1 -W 2 "$IP_LOCAL_BITAXE" > /dev/null 2>&1; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Error: Bitaxe en $IP_LOCAL_BITAXE no responde" >> ./bitaxe.log
        return 1
    fi

    response=$(curl -s http://$IP_LOCAL_BITAXE/api/system/info)
    if [ $? -ne 0 ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Error al obtener datos de la API" >> ./bitaxe.log
        return 1
    fi

    temperatura=$(echo "$response" | jq '(.temp * 10 + 0.05) | floor / 10')
    if [ -z "$temperatura" ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Error al extraer la temperatura" >> ./bitaxe.log
        return 1
    fi

    echo "$temperatura"
}

# Función para obtener la frecuencia actual del Bitaxe
obtener_frecuencia_actual() {
    response=$(curl -s http://$IP_LOCAL_BITAXE/api/system/info)
    if [ $? -ne 0 ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Error al obtener frecuencia de la API" >> ./bitaxe.log
        return 1
    fi

    frecuencia=$(echo "$response" | jq '.frequency')
    if [ -z "$frecuencia" ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Error al extraer la frecuencia" >> ./bitaxe.log
        return 1
    fi

    echo "$frecuencia"
}

# Función para cambiar la frecuencia del Bitaxe
cambiar_frecuencia() {
    local frecuencia="$1"
    local response
    response=$(curl -s -w "%{http_code}" -X PATCH http://$IP_LOCAL_BITAXE/api/system \
        -H "Content-Type: application/json" \
        -d "{\"display\":\"SSD1306 (128x32)\",\"rotation\":0,\"invertscreen\":false,\"displayTimeout\":-1,\"coreVoltage\":1150,\"frequency\":$frecuencia,\"autofanspeed\":true,\"temptarget\":60,\"overheat_mode\":0,\"statsFrequency\":0}" -o /dev/null)
    if [ "$response" != "200" ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Error al cambiar frecuencia a $frecuencia MHz: HTTP $response" >> ./bitaxe.log
        return 1
    fi
}

# Bucle principal para monitorear la temperatura
while true; do
    temperatura_actual=$(obtener_temperatura_bitaxe)

    if [ $? -eq 0 ]; then
        tiempo_actual=$(date +%s)
        frecuencia_actual=$(obtener_frecuencia_actual)

        # Verifica si la temperatura supera el límite
        if (( $(echo "$temperatura_actual > $TEMPERATURA_LIMITE" | bc -l) )); then
            if [ "$frecuencia_actual" != "400" ]; then
                cambiar_frecuencia 400
                enviar_aviso "¡ALERTA! Tu Bitaxe está a $temperatura_actual °C. Frecuencia ajustada a 400 MHz." 8
                ultimo_aviso=$tiempo_actual
            fi
        elif (( $(echo "$temperatura_actual < $TEMPERATURA_SEGURA" | bc -l) )); then
            # Cambia la frecuencia a 525 MHz si ha pasado más de una hora desde el último aviso
            if (( tiempo_actual - ultimo_aviso >= HORA_ALERTA )); then
                if [ "$frecuencia_actual" != "525" ]; then
                    cambiar_frecuencia 525
                    enviar_aviso "La temperatura ha bajado a $temperatura_actual °C. Frecuencia ajustada a 525 MHz." 5
                    ultimo_aviso=$tiempo_actual
                fi
            fi
        fi
    fi

    sleep 300  # Espera 5 minutos antes de volver a comprobar la temperatura
done
