# Bitaxe Temperature Monitor

Este script de Bash (`temp_bitaxe.sh`) monitorea la temperatura de un dispositivo Bitaxe a través de su API, ajusta la frecuencia (400 MHz o 525 MHz) según los umbrales de temperatura configurados, y envía notificaciones a un chat de Telegram cuando se realizan cambios. El script incluye registro de errores en un archivo local y verifica el estado actual para evitar cambios redundantes.

## Requisitos

- **Sistema operativo**: Linux (o cualquier sistema con Bash, `curl`, `jq`, `bc` y `screen` instalados).
- **Dependencias**:
  - `curl`: Para realizar solicitudes HTTP a la API de Bitaxe y Telegram.
  - `jq`: Para procesar respuestas JSON de la API de Bitaxe.
  - `bc`: Para cálculos con números decimales.
  - `screen`: Para ejecutar el script en una sesión persistente.
  - Instálalos en sistemas basados en Debian/Ubuntu con:
    ```bash
    sudo apt update
    sudo apt install curl jq bc screen
    ```
- **Acceso a la API de Bitaxe**: Asegúrate de que tu Bitaxe esté accesible en la red local (por ejemplo, `192.168.1.10`).
- **Bot de Telegram**: Necesitas un bot de Telegram y el ID del chat donde recibirás las notificaciones.

## Configuración del Bot de Telegram

1. **Crear un bot**:
   - Abre Telegram y habla con `@BotFather`.
   - Usa el comando `/newbot` y sigue las instrucciones para crear un bot.
   - Copia el **token** del bot (por ejemplo, `123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11`).

2. **Obtener el chat ID**:
   - Envía un mensaje al bot desde el chat donde quieres recibir las notificaciones (puede ser un chat privado o un grupo).
   - Ejecuta el siguiente comando para obtener el `chat_id`:
     ```bash
     curl -s https://api.telegram.org/bot<tu_token>/getUpdates
     ```
   - Busca el campo `chat.id` en la respuesta JSON (por ejemplo, `123456789`).
   - Nota: Si no ves el `chat_id`, asegúrate de haber enviado un mensaje al bot primero.

3. **Probar el bot**:
   - Envía un mensaje de prueba para verificar que el bot y el chat ID funcionan:
     ```bash
     curl -s -X POST https://api.telegram.org/bot<tu_token>/sendMessage -d "chat_id=<tu_chat_id>&text=Prueba"
     ```
   - Si recibes el mensaje en Telegram, la configuración es correcta.

## Instalación

1. **Descarga el script**:
   - Guarda el script `temp_bitaxe.sh` en un directorio de tu elección (por ejemplo, `/home/user/bitaxe/`).

2. **Crear el archivo de configuración**:
   - Crea un archivo llamado `bitaxe.conf` en el mismo directorio que el script.
   - Copia y pega el siguiente contenido, reemplazando los valores con los tuyos:
     ```bash
     # ./bitaxe.conf
     TELEGRAM_BOT_TOKEN="123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11"
     TELEGRAM_chat_id="123456789"
     TEMPERATURA_LIMITE=66
     TEMPERATURA_SEGURA=61
     HORA_ALERTA=7200
     IP_LOCAL_BITAXE=192.168.1.10
     ```
   - **Explicación de las variables**:
     - `TELEGRAM_BOT_TOKEN`: El token del bot de Telegram.
     - `TELEGRAM_CHAT_ID`: El ID del chat donde se enviarán las notificaciones.
     - `TEMPERATURA_LIMITE`: Temperatura máxima (en °C) para bajar la frecuencia a 400 MHz.
     - `TEMPERATURA_SEGURA`: Temperatura segura (en °C) para subir la frecuencia a 525 MHz.
     - `HORA_ALERTA`: Tiempo mínimo (en segundos) entre notificaciones para frecuencia alta (525 MHz).
     - `IP_LOCAL_BITAXE`: Dirección IP local de tu Bitaxe.

3. **Establecer permisos**:
   - Asegúrate de que el script sea ejecutable:
     ```bash
     chmod +x temp_bitaxe.sh
     ```
   - Protege el archivo de configuración para que solo el usuario que ejecuta el script pueda leerlo:
     ```bash
     chmod 600 bitaxe.conf
     ```

## Uso

### Ejecutar el script con `screen`

El script debe ejecutarse en una sesión persistente para que siga corriendo incluso después de cerrar la terminal. Usaremos `screen` para esto.

1. **Iniciar una sesión de `screen`**:
   - Abre una terminal y ejecuta:
     ```bash
     screen -S bitaxe_monitor
     ```
   - Esto crea una nueva sesión de `screen` llamada `bitaxe_monitor`.

2. **Ejecutar el script**:
   - Dentro de la sesión de `screen`, ejecuta:
     ```bash
     ./temp_bitaxe.sh
     ```
   - El script comenzará a monitorear la temperatura y enviar notificaciones a Telegram.

3. **Desconectar de la sesión de `screen`**:
   - Para dejar el script corriendo en segundo plano, presiona `Ctrl+A` seguido de `d` (esto desconecta la sesión sin detener el script).
   - Verás un mensaje como `[detached from 12345.bitaxe_monitor]`.

4. **Volver a la sesión de `screen`**:
   - Para regresar a la sesión y verificar el estado del script:
     ```bash
     screen -r bitaxe_monitor
     ```
   - Si solo tienes una sesión de `screen`, puedes usar simplemente `screen -r`.

5. **Detener el script**:
   - Dentro de la sesión de `screen`, presiona `Ctrl+C` para detener el script.
   - Luego, sal de la sesión con:
     ```bash
     exit
     ```

### Ejecutar el script automáticamente al iniciar el servidor

Para que el script se ejecute automáticamente dentro de una sesión de `screen` al encender el servidor, puedes agregar una entrada en `crontab`.

1. **Editar el `crontab`**:
   - Abre el editor de `crontab` para el usuario que ejecutará el script:
     ```bash
     crontab -e
     ```
   - Agrega la siguiente línea al final del archivo, reemplazando `/path/to/temp_bitaxe.sh` con la ruta completa al script (por ejemplo, `/home/user/bitaxe/temp_bitaxe.sh`):
     ```bash
     @reboot sleep 30 && screen -dmS bitaxe_monitor /bin/bash /path/to/temp_bitaxe.sh
     ```
   - **Explicación**:
     - `@reboot`: Ejecuta el comando al iniciar el servidor.
     - `sleep 30`: Espera 30 segundos para asegurar que la red esté disponible.
     - `screen -dmS bitaxe_monitor`: Inicia una sesión de `screen` en modo desatendido (`-dm`) con el nombre `bitaxe_monitor`.
     - `/bin/bash /path/to/temp_bitaxe.sh`: Ejecuta el script dentro de la sesión de `screen`.

2. **Verificar la sesión de `screen`**:
   - Después de reiniciar el servidor, verifica que la sesión de `screen` esté corriendo:
     ```bash
     screen -ls
     ```
   - Deberías ver algo como:
     ```
     There is a screen on:
         12345.bitaxe_monitor   (Detached)
     ```
   - Puedes reconectarte con `screen -r bitaxe_monitor` para inspeccionar.

## Funcionamiento

- **Monitoreo de temperatura**:
  - El script consulta la temperatura del Bitaxe cada 5 minutos a través de su API (`http://<IP_LOCAL_BITAXE>/api/system/info`).
  - Si la temperatura supera `TEMPERATURA_LIMITE` (66 °C por defecto), baja la frecuencia a 400 MHz y envía una notificación a Telegram con el prefijo `[ALTA PRIORIDAD]`.
  - Si la temperatura baja por debajo de `TEMPERATURA_SEGURA` (61 °C por defecto) y han pasado al menos `HORA_ALERTA` (2 hora) desde la última notificación, sube la frecuencia a 525 MHz y envía una notificación con el prefijo `[Normal]`.

- **Notificaciones**:
  - Las notificaciones se envían a través de la API de Telegram al chat especificado en `TELEGRAM_CHAT_ID`.
  - Ejemplo de mensajes:
    - `[ALTA PRIORIDAD] ¡ALERTA! Tu Bitaxe está a 67.5 °C. Frecuencia ajustada a 400 MHz.`
    - `[Normal] La temperatura ha bajado a 60.2 °C. Frecuencia ajustada a 525 MHz.`

- **Registro de errores**:
  - Los errores (como fallos de conexión al Bitaxe o Telegram) se registran en `./bitaxe.log` en el mismo directorio que el script.

## Depuración

- **Verificar el log**:
  - Si no recibes notificaciones o el script no funciona como esperas, revisa el archivo `./bitaxe.log`:
    ```bash
    cat ./bitaxe.log
    ```
  - Ejemplo de mensajes de error:
    - `2025-08-15 18:33:00 - Error: Bitaxe en 192.168.1.10 no responde`
    - `2025-08-15 18:33:00 - Error al enviar notificación a Telegram: HTTP 401`

- **Probar la conexión al Bitaxe**:
  - Verifica que la API del Bitaxe esté accesible:
    ```bash
    curl http://<IP_LOCAL_BITAXE>/api/system/info
    ```

- **Verificar la sesión de `screen`**:
  - Si el script no parece estar corriendo, verifica si la sesión de `screen` está activa:
    ```bash
    screen -ls
    ```
## Compatibilidad

Este script ha sido probado en un **Bitaxe Gamma** con **AxeOS**. Debería funcionar con otros modelos de Bitaxe que usen **AxeOS**, aunque la compatibilidad con otros modelos no ha sido verificada.

## Notas

- **Seguridad**: El archivo `bitaxe.conf` contiene el token del bot de Telegram, que es sensible. Asegúrate de que solo el usuario que ejecuta el script tenga acceso a este archivo.
- **Gestión del log**: El archivo `./bitaxe.log` puede crecer con el tiempo. Considera limpiarlo periódicamente o implementar un script para rotar logs manualmente.
- **Personalización**: Puedes ajustar los umbrales de temperatura (`TEMPERATURA_LIMITE`, `TEMPERATURA_SEGURA`) y el intervalo de notificaciones (`HORA_ALERTA`) en `bitaxe.conf`.

## License

This project is licensed under the [MIT License](LICENSE).
