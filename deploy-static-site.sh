#!/bin/bash

echo "===== DEPLOY STATIC SITE + CLOUDFLARE 🚀 ====="

read -p "Dominio (ej: midominio.com): " DOMAIN
read -p "Nombre del túnel (ej: byteobe-tunnel): " TUNNEL_NAME
read -p "Ruta credenciales (ej: /root/.cloudflared/xxx.json): " CREDENTIALS

WWW_PATH="/var/www/$DOMAIN"
NGINX_AVAILABLE="/etc/nginx/sites-available/$DOMAIN"
NGINX_ENABLED="/etc/nginx/sites-enabled/$DOMAIN"
CLOUDFLARED_CONFIG="/etc/cloudflared/config.yml"

echo "===== CREANDO DIRECTORIO ====="
mkdir -p $WWW_PATH
chown -R www-data:www-data $WWW_PATH

echo "===== CREANDO INDEX POR DEFECTO ====="
cat > $WWW_PATH/index.html <<EOF
<h1>🚀 $DOMAIN funcionando</h1>
<p>Configurado con Cloudflare Tunnel</p>
EOF

echo "===== CONFIGURANDO NGINX ====="
cat > $NGINX_AVAILABLE <<EOF
server {
    listen 80;
    server_name $DOMAIN www.$DOMAIN;

    root $WWW_PATH;
    index index.html;

    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF

ln -sf $NGINX_AVAILABLE $NGINX_ENABLED

echo "===== VALIDANDO NGINX ====="
nginx -t || { echo "Error en nginx"; exit 1; }

systemctl reload nginx

echo "===== CONFIGURANDO CLOUDFLARED (SIN BORRAR) ====="

# Si no existe config.yml, lo crea base
if [ ! -f "$CLOUDFLARED_CONFIG" ]; then
cat > $CLOUDFLARED_CONFIG <<EOF
tunnel: $TUNNEL_NAME
credentials-file: $CREDENTIALS

ingress:
EOF
fi

# Evita duplicados
if grep -q "$DOMAIN" "$CLOUDFLARED_CONFIG"; then
    echo "⚠️ El dominio ya existe en cloudflared, no se agrega"
else
    # Inserta antes de la última línea (http_status:404)
    sed -i "/http_status:404/i\  - hostname: $DOMAIN\n    service: http://localhost:80\n\n  - hostname: www.$DOMAIN\n    service: http://localhost:80\n" $CLOUDFLARED_CONFIG
fi

echo "===== REINICIANDO CLOUDFLARED ====="
systemctl restart cloudflared

echo "===== STATUS ====="
systemctl status cloudflared --no-pager

echo "===== LISTO 🚀 ====="
echo "👉 Sube tus archivos a: $WWW_PATH"
echo "👉 Tu web estará en: https://$DOMAIN"
