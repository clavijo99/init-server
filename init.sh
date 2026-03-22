#!/bin/bash

# ===== VALIDAR ROOT =====
if [ "$EUID" -ne 0 ]; then
  echo "❌ Este script debe ejecutarse como root"
  echo "👉 Usa: sudo ./init.sh"
  exit 1
fi

echo "===== SETUP CLOUDFLARE TUNNEL + SSH ====="

read -p "Dominio (ej: midominio.com): " DOMAIN
read -p "Subdominio SSH (ej: ssh, ssh.vm1, ssh.prod): " SUBDOMAIN

# validar subdominio
if [ -z "$SUBDOMAIN" ]; then
  echo "❌ El subdominio no puede estar vacío"
  exit 1
fi

echo "===== PEGA TU LLAVE PÚBLICA SSH ====="
echo "(ej: ssh-ed25519 AAAA... tu-email)"
read -p "SSH KEY: " SSH_KEY

if [[ "$SSH_KEY" != ssh-* ]]; then
  echo "❌ Llave SSH inválida"
  exit 1
fi

TUNNEL_NAME="tunnel-$HOSTNAME"

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

# ===== CONFIGURAR SSH =====
echo "===== CONFIGURANDO SSH KEY ====="

mkdir -p /root/.ssh
touch /root/.ssh/authorized_keys

grep -qxF "$SSH_KEY" /root/.ssh/authorized_keys || echo "$SSH_KEY" >> /root/.ssh/authorized_keys

chmod 700 /root/.ssh
chmod 600 /root/.ssh/authorized_keys

echo "===== HARDENING SSH ====="

sed -i 's/^#\?PasswordAuthentication .*/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#\?ChallengeResponseAuthentication .*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#\?UsePAM .*/UsePAM no/' /etc/ssh/sshd_config
sed -i 's/^#\?PermitRootLogin .*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
sed -i 's/^#\?PubkeyAuthentication .*/PubkeyAuthentication yes/' /etc/ssh/sshd_config

systemctl restart ssh

# ===== CONFIG CLOUDFLARE =====
echo "===== CREANDO CONFIG CLOUDFLARE ====="

mkdir -p /etc/cloudflared

cat <<EOF > /etc/cloudflared/config.yml
tunnel: $TUNNEL_ID
credentials-file: /root/.cloudflared/$TUNNEL_ID.json

logfile: /var/log/cloudflared.log
loglevel: info

ingress:
  - hostname: $SUBDOMAIN.$DOMAIN
    service: ssh://localhost:22

  - service: http_status:404
EOF

echo "===== CREANDO DNS ====="
cloudflared tunnel route dns $TUNNEL_NAME $SUBDOMAIN.$DOMAIN

echo "===== INSTALANDO SERVICIO ====="
cloudflared service install

echo "===== ACTIVANDO SERVICIO ====="
systemctl enable cloudflared
systemctl restart cloudflared

echo "===== ESTADO ====="
systemctl status cloudflared --no-pager

echo "===== LISTO 🚀 ====="
echo "Conéctate con:"
echo "ssh root@$SUBDOMAIN.$DOMAIN"
