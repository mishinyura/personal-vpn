#!/bin/bash
set -e

SERVER_IP=$(curl -s ifconfig.me)   # get public IP automatically

echo "🔧 Setting up OpenVPN + Nginx stack..."
mkdir -p openvpn nginx/conf.d nginx/html

# Create default Nginx config if not exists
if [ ! -f nginx/conf.d/default.conf ]; then
cat > nginx/conf.d/default.conf <<EOF
server {
    listen 80;
    server_name $SERVER_IP;

    location / {
        root /usr/share/nginx/html;
        index index.html;
    }
}
EOF
fi

# Create default index.html if not exists
if [ ! -f nginx/html/index.html ]; then
cat > nginx/html/index.html <<EOF
<!DOCTYPE html>
<html>
<head>
  <title>Nginx + OpenVPN Service</title>
</head>
<body>
  <h1>Welcome to your Nginx + OpenVPN Server 🚀</h1>
</body>
</html>
EOF
fi

# Generate OpenVPN configs if first run
if [ ! -f openvpn/openvpn.conf ]; then
  echo "📦 Initializing OpenVPN configuration..."
  docker run -v $(pwd)/openvpn:/etc/openvpn --rm kylemanna/openvpn ovpn_genconfig -u udp://$SERVER_IP:443
  docker run -v $(pwd)/openvpn:/etc/openvpn --rm -it kylemanna/openvpn ovpn_initpki
fi

# Start services
docker compose up -d

# Create client profile
CLIENT_NAME="myclient"
docker run -v $(pwd)/openvpn:/etc/openvpn --rm -it kylemanna/openvpn easyrsa build-client-full $CLIENT_NAME nopass || true
docker run -v $(pwd)/openvpn:/etc/openvpn --rm kylemanna/openvpn ovpn_getclient $CLIENT_NAME > ${CLIENT_NAME}.ovpn

echo "✅ Setup complete!"
echo "➡ Import ${CLIENT_NAME}.ovpn into OpenVPN Connect."

# Create VPN users directory
mkdir -p vpn-users

# Create admin credentials
ADMIN_USER="admin"
ADMIN_PASS=$(openssl rand -hex 8)

echo "${ADMIN_USER}:${ADMIN_PASS}" > vpn-users/credentials
chmod 600 vpn-users/credentials

echo "🔑 Admin VPN credentials created:"
echo "   Username: ${ADMIN_USER}"
echo "   Password: ${ADMIN_PASS}"

# Configure OpenVPN to use password auth
if ! grep -q "plugin /usr/lib/openvpn/openvpn-plugin-auth-pam.so login" openvpn/openvpn.conf; then
    echo "plugin /usr/lib/openvpn/openvpn-plugin-auth-pam.so login" >> openvpn/openvpn.conf
    echo "verify-client-cert none" >> openvpn/openvpn.conf
    echo "username-as-common-name" >> openvpn/openvpn.conf
fi

