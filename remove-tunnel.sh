#!/bin/bash

# ===== VALIDAR ROOT =====

if [ "$EUID" -ne 0 ]; then
echo "❌ Ejecuta como root: sudo ./remove-tunnel.sh"
exit 1
fi

echo "===== CLOUDFLARE TUNNELS DISPONIBLES ====="
cloudflared tunnel list

echo ""
read -p "👉 Escribe el nombre EXACTO del tunnel a eliminar: " TUNNEL_NAME

if [ -z "$TUNNEL_NAME" ]; then
echo "❌ Debes indicar el nombre del tunnel"
exit 1
fi

# ===== VALIDAR EXISTENCIA =====

TUNNEL_ID=$(cloudflared tunnel list | grep -w "$TUNNEL_NAME" | awk '{print $1}')

if [ -z "$TUNNEL_ID" ]; then
echo "❌ Tunnel no encontrado"
exit 1
fi

echo ""
echo "⚠️ Vas a eliminar el tunnel: $TUNNEL_NAME ($TUNNEL_ID)"
read -p "¿Confirmar eliminación? (y/n): " CONFIRM

if [[ "$CONFIRM" != "y" ]]; then
echo "❌ Cancelado"
exit 0
fi

echo "===== DETENER SERVICIO ====="
systemctl stop cloudflared 2>/dev/null
systemctl disable cloudflared 2>/dev/null

echo "===== ELIMINANDO DNS ====="
cloudflared tunnel route dns delete $TUNNEL_NAME 2>/dev/null || true

echo "===== ELIMINANDO TUNNEL ====="
cloudflared tunnel delete $TUNNEL_NAME

echo "===== BORRANDO ARCHIVOS ====="
rm -f /root/.cloudflared/$TUNNEL_ID.json
rm -f /etc/cloudflared/config.yml
rm -f /var/log/cloudflared.log

echo "===== OPCIONAL: DESINSTALAR CLOUDFLARED ====="
read -p "¿Quieres eliminar cloudflared del sistema? (y/n): " REMOVE_BIN

if [[ "$REMOVE_BIN" == "y" ]]; then
apt remove -y cloudflared
fi

echo ""
echo "===== LISTO 🧹 ====="
