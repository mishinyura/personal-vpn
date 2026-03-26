#!/usr/bin/env bash
set -Eeuo pipefail

DOMAIN_OR_IP="${1:-}"
CLIENTS=("admin" "iman" "paria")

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "❌ Required command not found: $1"
    exit 1
  }
}

detect_endpoint() {
  if [[ -n "${DOMAIN_OR_IP}" ]]; then
    echo "${DOMAIN_OR_IP}"
    return
  fi

  curl -4 -fsSL ifconfig.me || {
    echo "❌ Could not detect public IP automatically."
    echo "Usage: ./setup.sh YOUR_DOMAIN_OR_IP"
    exit 1
  }
}

check_port_free_tcp() {
  local port="$1"
  if ss -tulpn 2>/dev/null | grep -qE "[[:space:]]:${port}[[:space:]]"; then
    echo "⚠️ Port ${port} appears to be in use."
    ss -tulpn | grep -E "[[:space:]]:${port}[[:space:]]" || true
  fi
}

echo "🔧 Setting up OpenVPN + Nginx stack..."

require_cmd docker
require_cmd curl
require_cmd openssl
require_cmd ss

if ! docker compose version >/dev/null 2>&1; then
  echo "❌ docker compose plugin not found."
  exit 1
fi

ENDPOINT="$(detect_endpoint)"
VPN_PROTO="udp"
VPN_PORT="443"
NGINX_PORT="8080"

echo "🌐 VPN endpoint: ${ENDPOINT}"
echo "📡 OpenVPN will listen on: ${VPN_PROTO}://${ENDPOINT}:${VPN_PORT}"
echo "🌍 Nginx will be available on: http://${ENDPOINT}:${NGINX_PORT}"

mkdir -p openvpn nginx/conf.d nginx/html

cat > nginx/conf.d/default.conf <<'EOF'
server {
    listen 80 default_server;
    server_name _;

    root /usr/share/nginx/html;
    index index.html;

    location / {
        try_files $uri $uri/ =404;
    }
}
EOF

cat > nginx/html/index.html <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>VPN Server</title>
</head>
<body>
  <h1>OpenVPN + Nginx is running</h1>
  <p>VPN endpoint: ${ENDPOINT}:${VPN_PORT}/udp</p>
  <p>Nginx endpoint: http://${ENDPOINT}:${NGINX_PORT}</p>
</body>
</html>
EOF

# safer idempotency checks
if [[ ! -f openvpn/openvpn.conf || ! -d openvpn/pki ]]; then
  echo "📦 Initializing OpenVPN server config and PKI..."

  docker run --rm \
    -v "$(pwd)/openvpn:/etc/openvpn" \
    kylemanna/openvpn \
    ovpn_genconfig -u "${VPN_PROTO}://${ENDPOINT}:${VPN_PORT}"

  docker run --rm \
    -v "$(pwd)/openvpn:/etc/openvpn" \
    -e EASYRSA_BATCH=1 \
    kylemanna/openvpn \
    ovpn_initpki nopass
else
  echo "ℹ️ Existing OpenVPN config detected, skipping PKI init."
fi

echo "🚀 Starting containers..."
docker compose up -d

echo "👤 Generating client certificates..."
for client in "${CLIENTS[@]}"; do
  if [[ -f "${client}.ovpn" ]]; then
    echo "  ℹ️ ${client}.ovpn already exists, skipping"
    continue
  fi

  docker run --rm \
    -v "$(pwd)/openvpn:/etc/openvpn" \
    kylemanna/openvpn \
    easyrsa build-client-full "${client}" nopass

  docker run --rm \
    -v "$(pwd)/openvpn:/etc/openvpn" \
    kylemanna/openvpn \
    ovpn_getclient "${client}" > "${client}.ovpn"

  echo "  ✅ generated ${client}.ovpn"
done

cat > VPN_CONNECTION_INSTRUCTIONS.txt <<EOF
OpenVPN Connection Instructions
===============================

Server endpoint:
  ${ENDPOINT}:${VPN_PORT}/udp

Generated client profiles:
$(for client in "${CLIENTS[@]}"; do echo "  - ${client}.ovpn"; done)

How to connect:
1. Install an OpenVPN client.
2. Import one of the .ovpn files.
3. Connect.

Notes:
- This setup uses certificate-based authentication.
- Nginx test page is available at:
  http://${ENDPOINT}:${NGINX_PORT}

Generated on: $(date)
EOF

echo
echo "✅ Setup complete"
echo "📄 Generated client profiles:"
ls -1 *.ovpn 2>/dev/null || true
echo
echo "📝 Instructions saved to VPN_CONNECTION_INSTRUCTIONS.txt"
echo
echo "🔎 Current container status:"
docker compose ps
echo
echo "🔎 Port check:"
check_port_free_tcp 80
check_port_free_tcp 8080
