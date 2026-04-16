@@ -1,84 +1,11 @@
#!/bin/bash

# ===== VALIDAR ROOT =====


if [ "$EUID" -ne 0 ]; then
echo "❌ Ejecuta como root"
exit 1
fi

echo "===== CLOUDFLARE SETUP 🚀 ====="

read -p "Tunnel name: " TUNNEL_NAME
read -p "Domain: " DOMAIN
read -p "Subdomain: " SUBDOMAIN
read -p "SSH KEY: " SSH_KEY
if [[ -z "${SSH_KEY// }" ]]; then
  SSH_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHWcmgRRfJQrUPXVT+P80O3f3f9Y9sAVBvjJe8Y3y5ui gomez@CamiloGomez"
fi

# ===== CLOUDFLARED =====

if ! command -v cloudflared &> /dev/null; then
wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
dpkg -i cloudflared-linux-amd64.deb
apt-get install -f -y
fi

# ===== LOGIN =====

[ ! -f /root/.cloudflared/cert.pem ] && cloudflared tunnel login

# ===== TUNNEL =====

EXISTING=$(cloudflared tunnel list | grep -w "$TUNNEL_NAME")

if [ ! -z "$EXISTING" ]; then
echo "⚠️ Tunnel existe"
read -p "Eliminar y recrear? (y/n): " OP

if [[ "$OP" == "y" || "$OP" == "Y" ]]; then
cloudflared tunnel delete $TUNNEL_NAME
sleep 2
cloudflared tunnel create $TUNNEL_NAME
fi
else
cloudflared tunnel create $TUNNEL_NAME
fi

TUNNEL_ID=$(cloudflared tunnel list | grep -w "$TUNNEL_NAME" | awk '{print $1}')

# ===== SSH =====

mkdir -p /root/.ssh
touch /root/.ssh/authorized_keys
grep -qxF "$SSH_KEY" /root/.ssh/authorized_keys || echo "$SSH_KEY" >> /root/.ssh/authorized_keys

chmod 700 /root/.ssh
chmod 600 /root/.ssh/authorized_keys

sed -i 's/^#?PasswordAuthentication .*/PasswordAuthentication no/' /etc/ssh/sshd_config
systemctl restart ssh

# ===== CONFIG YAML (SAFE) =====

echo "===== WRITING CONFIG ====="

mkdir -p /etc/cloudflared

printf "tunnel: %s\n" "$TUNNEL_ID" > /etc/cloudflared/config.yml
printf "credentials-file: /root/.cloudflared/%s.json\n\n" "$TUNNEL_ID" >> /etc/cloudflared/config.yml
printf "ingress:\n" >> /etc/cloudflared/config.yml
printf "  - hostname: %s.%s\n" "$SUBDOMAIN" "$DOMAIN" >> /etc/cloudflared/config.yml
printf "    service: ssh://localhost:22\n" >> /etc/cloudflared/config.yml
printf "  - service: http_status:404\n" >> /etc/cloudflared/config.yml

# ===== DNS =====

cloudflared tunnel route dns $TUNNEL_NAME $SUBDOMAIN.$DOMAIN

# ===== SERVICE =====

cloudflared service install
systemctl enable cloudflared
systemctl restart cloudflared

echo "===== DONE 🚀 ====="
echo "ssh root@$SUBDOMAIN.$DOMAIN"
