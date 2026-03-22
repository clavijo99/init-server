#!/bin/bash

CONFIG_FILE="/etc/cloudflared/config.yml"

echo "===== AGREGAR APP A CLOUDFLARE TUNNEL ====="

# validar root
if [ "$EUID" -ne 0 ]; then
  echo "❌ Ejecuta como root: sudo ./add-app.sh"
  exit 1
fi

# pedir datos
read -p "Subdominio (ej: app.byteobe.com): " HOSTNAME
read -p "Servicio interno (ej: http://localhost:3000 o ssh://localhost:22): " SERVICE

if [ -z "$HOSTNAME" ] || [ -z "$SERVICE" ]; then
  echo "❌ Todos los campos son obligatorios"
  exit 1
fi

# validar archivo config
if [ ! -f "$CONFIG_FILE" ]; then
  echo "❌ No existe $CONFIG_FILE"
  exit 1
fi

# evitar duplicados
if grep -q "$HOSTNAME" "$CONFIG_FILE"; then
  echo "⚠️ Ya existe ese hostname en config"
  exit 1
fi

echo "===== AGREGANDO AL CONFIG ====="

# insertar antes del http_status:404
sed -i "/service: http_status:404/i \\
  - hostname: $HOSTNAME\\
    service: $SERVICE\\
" $CONFIG_FILE

echo "===== NUEVA CONFIG ====="
cat $CONFIG_FILE

echo "===== REINICIANDO CLOUDFLARED ====="
systemctl restart cloudflared

sleep 2

systemctl status cloudflared --no-pager

echo "===== LISTO 🚀 ====="
echo "Tu app está disponible en:"
echo "👉 https://$HOSTNAME"
