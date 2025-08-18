#!/bin/bash
set -e

SERVER_IP=$(curl -s ifconfig.me)
VPN_USERS=("admin" "iman" "paria")  # Array of users to create

echo "🔧 Setting up OpenVPN + Nginx stack..."

# Create necessary directories
mkdir -p openvpn nginx/conf.d nginx/html vpn-users

# Create Nginx config
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

# Create default index.html
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

# Initialize OpenVPN if not already done
if [ ! -f openvpn/openvpn.conf ]; then
  echo "📦 Initializing OpenVPN configuration..."
  docker run -v $(pwd)/openvpn:/etc/openvpn --rm kylemanna/openvpn ovpn_genconfig -u udp://$SERVER_IP:443
  # Non-interactive CA init (no passphrase)
  docker run -v $(pwd)/openvpn:/etc/openvpn --rm \
    -e EASYRSA_BATCH=1 \
    -e EASYRSA_REQ_CN="VPN-Server" \
    -e EASYRSA_PASSIN= \
    -e EASYRSA_PASSOUT= \
    kylemanna/openvpn ovpn_initpki nopass
fi

# Create VPN users credentials file
echo "🔐 Generating credentials and certificates for users..."
> vpn-users/credentials  # Clear existing credentials

for USER in "${VPN_USERS[@]}"; do
  # Generate random password
  PASSWORD=$(openssl rand -hex 8)
  
  # Add to credentials file
  echo "$USER:$PASSWORD" >> vpn-users/credentials
  
  # Generate client certificate without password
  docker run -v $(pwd)/openvpn:/etc/openvpn --rm \
    kylemanna/openvpn easyrsa build-client-full $USER nopass >/dev/null 2>&1 || true
  
  # Generate .ovpn file
  docker run -v $(pwd)/openvpn:/etc/openvpn --rm \
    kylemanna/openvpn ovpn_getclient $USER > ${USER}.ovpn
  
  # Modify .ovpn to include credentials reference
  sed -i '/auth-user-pass/a auth-user-pass /etc/openvpn/ovpn-credentials/credentials' ${USER}.ovpn
  
  echo "  ✅ $USER - Password: $PASSWORD - Config: ${USER}.ovpn"
done

chmod 600 vpn-users/credentials

# Start services
echo "🚀 Starting Docker containers..."
docker compose up -d

# Create connection instructions file
cat > VPN_CONNECTION_INSTRUCTIONS.txt <<EOF
OpenVPN Connection Instructions
===============================

Server IP: $SERVER_IP

User Credentials:
$(for USER in "${VPN_USERS[@]}"; do
  PASSWORD=$(grep "^$USER:" vpn-users/credentials | cut -d: -f2)
  echo "- $USER : $PASSWORD"
done)

To connect:
1. Import the .ovpn file into your OpenVPN client
2. When prompted, enter your username and password above
3. Enjoy secure browsing!

Generated on: $(date)
EOF

echo "✅ Setup complete!"
echo "📄 VPN configuration files generated:"
ls -1 *.ovpn
echo "📝 Connection instructions saved to: VPN_CONNECTION_INSTRUCTIONS.txt"