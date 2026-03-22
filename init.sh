#!/bin/bash

# ===== VALIDAR ROOT =====

if [ "$EUID" -ne 0 ]; then
echo "❌ Ejecuta como root: sudo ./init.sh"
exit 1
fi

echo "===== SETUP CLOUDFLARE TUNNEL + SSH 🚀 ====="

# ===== INPUTS =====

read -p "Nombre del tunnel: " TUNNEL_NAME
read -p "Dominio (ej: midominio.com): " DOMAIN
read -p "Subdominio SSH (ej: ssh, ssh.vm1): " SUBDOMAIN

if [ -z "$TUNNEL_NAME" ] || [ -z "$DOMAIN" ] || [ -z "$SUBDOMAIN" ]; then
echo "❌ Datos incompletos"
exit 1
fi

echo ""
read -p "SSH KEY: " SSH_KEY

if [[ "$SSH_KEY" != ssh-* ]]; then
echo "❌ Llave SSH inválida"
exit 1
fi

# ===== INSTALAR CLOUDFLARED =====

echo "===== INSTALANDO CLOUDFLARED ====="
if ! command -v cloudflared &> /dev/null; then
wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
dpkg -i cloudflared-linux-amd64.deb
apt-get install -f -y
fi

# ===== LOGIN SOLO SI NO EXISTE =====

if [ ! -f /root/.cloudflared/cert.pem ]; then
echo "===== LOGIN EN CLOUDFLARE ====="
cloudflared tunnel login
else
echo "✔ Ya autenticado en Cloudflare"
fi

# ===== CREAR O REUTILIZAR =====

echo "===== CONFIGURANDO TUNNEL ====="

EXISTING=$(cloudflared tunnel list | grep -w "$TUNNEL_NAME")

if [ -z "$EXISTING" ]; then
cloudflared tunnel create $TUNNEL_NAME
else
echo "✔ Tunnel ya existe"
fi

TUNNEL_ID=$(cloudflared tunnel list | grep -w "$TUNNEL_NAME" | awk '{print $1}')

if [ -z "$TUNNEL_ID" ]; then
echo "❌ No se pudo obtener TUNNEL_ID"
exit 1
fi

echo "Tunnel ID: $TUNNEL_ID"

# ===== SSH =====

echo "===== CONFIGURANDO SSH ====="

mkdir -p /root/.ssh
touch /root/.ssh/authorized_keys

grep -qxF "$SSH_KEY" /root/.ssh/authorized_keys || echo "$SSH_KEY" >> /root/.ssh/authorized_keys

chmod 700 /root/.ssh
chmod 600 /root/.ssh/authorized_keys

# ===== HARDENING =====

echo "===== HARDENING SSH ====="

sed -i 's/^#?PasswordAuthentication .*/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#?ChallengeResponseAuthentication .*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#?UsePAM .*/UsePAM no/' /etc/ssh/sshd_config
sed -i 's/^#?PermitRootLogin .*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
sed -i 's/^#?PubkeyAuthentication .*/PubkeyAuthentication yes/' /etc/ssh/sshd_config

systemctl restart ssh

# ===== CONFIG CLOUDFLARE =====

echo "===== CREANDO CONFIG YAML ====="

mkdir -p /etc/cloudflared

cat <<EOF > /etc/cloudflared/config.yml
tunnel: $TUNNEL_ID
credentials-file: /root/.cloudflared/$TUNNEL_ID.json

ingress:

* hostname: $SUBDOMAIN.$DOMAIN
  service: ssh://localhost:22
* service: http_status:404
  EOF

# ===== VALIDAR YAML =====

echo "===== VALIDANDO CONFIG ====="

cloudflared tunnel list > /dev/null 2>&1

if [ $? -ne 0 ]; then
echo "❌ YAML inválido, revisa config.yml"
exit 1
fi

# ===== DNS =====

echo "===== CONFIGURANDO DNS ====="
cloudflared tunnel route dns $TUNNEL_NAME $SUBDOMAIN.$DOMAIN

# ===== SERVICIO =====

echo "===== INICIANDO SERVICIO ====="

cloudflared service install
systemctl enable cloudflared
systemctl restart cloudflared

# ===== FINAL =====

echo ""
echo "===== LISTO 🚀 ====="
echo "ssh root@$SUBDOMAIN.$DOMAIN"
