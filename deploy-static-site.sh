#!/bin/bash

echo "===== DEPLOY STATIC SITE 🚀 ====="

# validar root
if [ "$EUID" -ne 0 ]; then
  echo "❌ Ejecuta como root: sudo ./deploy-static-site.sh"
  exit 1
fi

# pedir datos
read -p "Dominio (ej: midominio.com): " DOMAIN
read -p "Email para SSL (ej: correo@gmail.com): " EMAIL

if [ -z "$DOMAIN" ] || [ -z "$EMAIL" ]; then
  echo "❌ Dominio y email son obligatorios"
  exit 1
fi

WEB_ROOT="/var/www/$DOMAIN"
NGINX_AVAILABLE="/etc/nginx/sites-available/$DOMAIN"
NGINX_ENABLED="/etc/nginx/sites-enabled/$DOMAIN"

echo "===== CREANDO DIRECTORIO ====="

mkdir -p $WEB_ROOT
chown -R www-data:www-data $WEB_ROOT
chmod -R 755 $WEB_ROOT

# crear index de prueba
cat <<EOF > $WEB_ROOT/index.html
<!DOCTYPE html>
<html>
<head>
  <title>$DOMAIN</title>
</head>
<body>
  <h1>🚀 Sitio funcionando en $DOMAIN</h1>
</body>
</html>
EOF

echo "===== CONFIGURANDO NGINX ====="

cat <<EOF > $NGINX_AVAILABLE
server {
    listen 80;
    server_name $DOMAIN www.$DOMAIN;

    root $WEB_ROOT;
    index index.html;

    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF

ln -sf $NGINX_AVAILABLE $NGINX_ENABLED

echo "===== REINICIANDO NGINX ====="

systemctl reload nginx

echo "===== INSTALANDO CERTBOT ====="

apt update
apt install -y certbot python3-certbot-nginx

echo "===== GENERANDO SSL ====="

certbot --nginx -d $DOMAIN -d www.$DOMAIN --non-interactive --agree-tos -m $EMAIL --redirect

echo "===== VERIFICANDO RENOVACIÓN ====="

systemctl enable certbot.timer
systemctl start certbot.timer

echo "===== LISTO 🚀 ====="
echo "👉 https://$DOMAIN"
