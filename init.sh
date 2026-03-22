#!/bin/bash

# ===== VALIDAR ROOT =====

if [ "$EUID" -ne 0 ]; then
echo "❌ Este script debe ejecutarse como root"
echo "👉 Usa: sudo ./init.sh"
exit 1
fi

echo "===== SETUP CLOUDFLARE TUNNEL + SSH ====="

read -p "Nombre del tunnel (ej: tunnel-prod, ssh-vm1): " TUNNEL_NAME
read -p "Dominio (ej: midominio.com): " DOMAIN
read -p "Subdominio SSH (ej: ssh, ssh.vm1, ssh.prod): " SUBDOMAIN

if [ -z "$TUNNEL_NAME" ] || [ -z "$SUBDOMAIN" ]; then
echo "❌ Datos incompletos"
exit 1
fi

echo "===== PEGA TU LLAVE PÚBLICA SSH ====="
read -p "SSH KEY: " SSH_KEY

if [[ "$SSH_KEY" != ssh-* ]]; then
echo "❌ Llave SSH inválida"
exit 1
fi

echo "===== INSTALANDO CLOUDFLARED ====="
wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
dpkg -i cloudflared-linux-amd64.deb
apt-get install -f -y

which cloudflared || { echo "❌ cloudflared no instalado"; exit 1; }

echo "===== LOGIN EN CLOUDFLARE ====="
cloudflared tunnel login

echo "===== CREANDO TUNNEL ====="
cloudflared tunnel create $TUNNEL_NAME

TUNNEL_ID=$(cloudflared tunnel list | grep $TUNNEL_NAME | awk '{print $1}')

if [ -z "$TUNNEL_ID" ]; then
echo "❌ No se pudo obtener TUNNEL_ID"
exit 1
fi

echo "Tunnel ID: $TUNNEL_ID"

# ===== SSH =====

mkdir -p /root/.ssh
touch /root/.ssh/authorized_keys

grep -qxF "$SSH_KEY" /root/.ssh/authorized_keys || echo "$SSH_KEY" >> /root/.ssh/authorized_keys

chmod 700 /root/.ssh
chmod 600 /root/.ssh/authorized_keys

# ===== HARDENING SSH =====

sed -i 's/^#?PasswordAuthentication .*/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#?ChallengeResponseAuthentication .*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#?UsePAM .*/UsePAM no/' /etc/ssh/sshd_config
sed -i 's/^#?PermitRootLogin .*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
sed -i 's/^#?PubkeyAuthentication .*/PubkeyAuthentication yes/' /etc/ssh/sshd_config

systemctl restart ssh

# ===== CLOUDFLARE CONFIG =====

mkdir -p /etc/cloudflared

cat <<EOF > /etc/cloudflared/config.yml
tunnel: $TUNNEL_ID
credentials-file: /root/.cloudflared/$TUNNEL_ID.json

ingress:

* hostname: $SUBDOMAIN.$DOMAIN
  service: ssh://localhost:22
* service: http_status:404
  EOF

echo "===== CREANDO DNS ====="
cloudflared tunnel route dns $TUNNEL_NAME $SUBDOMAIN.$DOMAIN

echo "===== SERVICIO ====="
cloudflared service install
systemctl enable cloudflared
systemctl restart cloudflared

echo "===== LISTO 🚀 ====="
echo "ssh root@$SUBDOMAIN.$DOMAIN"
