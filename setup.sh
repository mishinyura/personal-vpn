#!/bin/bash
set -e

SERVER_IP=$(curl -s ifconfig.me)

echo "🔧 Setting up OpenVPN + Nginx stack..."

mkdir -p openvpn nginx/conf.d nginx/html vpn-users

# Default Nginx config
cat > nginx/conf.d/default.conf <<EOF
server {
    listen 80;
    server_name mezgls.ir;

    location / {
        root /usr/share/nginx/html;
        index index.html;
    }
}
EOF

# Default index.html
cat > nginx/html/index.html <<EOF
<!DOCTYPE html>
<html>
<head>
  <title>Nginx + OpenVPN</title>
</head>
<body>
  <h1>Welcome to your Nginx + OpenVPN Server 🚀</h1>
</body>
</html>
EOF

# Initialize OpenVPN non-interactive
if [ ! -f openvpn/openvpn.conf ]; then
  echo "📦 Initializing OpenVPN configuration..."
  docker run -v $(pwd)/openvpn:/etc/openvpn --rm kylemanna/openvpn ovpn_genconfig -u udp://$SERVER_IP:443
  docker run -v $(pwd)/openvpn:/etc/openvpn --rm -e EASYRSA_BATCH=1 -e EASYRSA_PASSIN= -e EASYRSA_PASSOUT= kylemanna/openvpn ovpn_initpki
fi

# Create VPN users credentials
echo "admin:$(openssl rand -hex 8)" > vpn-users/credentials
echo "iman:$(openssl rand -hex 8)" >> vpn-users/credentials
echo "paria:$(openssl rand -hex 8)" >> vpn-users/credentials
chmod 600 vpn-users/credentials

# Start services
docker compose up -d

# Generate .ovpn for all users
for USER in admin iman paria; do
  docker run -v $(pwd)/openvpn:/etc/openvpn --rm kylemanna/openvpn easyrsa build-client-full $USER nopass || true
  docker run -v $(pwd)/openvpn:/etc/openvpn --rm kylemanna/openvpn ovpn_getclient $USER > ${USER}.ovpn
done

echo "✅ Setup complete! .ovpn files generated for admin, iman, and paria."
