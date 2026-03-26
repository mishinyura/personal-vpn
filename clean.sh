#!/usr/bin/env bash
set -Eeuo pipefail

echo "⚠️ This will DELETE:"
echo "  - containers"
echo "  - OpenVPN config and PKI"
echo "  - nginx config/html"
echo "  - generated client .ovpn files"
read -r -p "Type YES to continue: " CONFIRM

if [[ "${CONFIRM}" != "YES" ]]; then
  echo "Aborted."
  exit 1
fi

echo "🧹 Stopping and removing Docker services..."
docker compose down -v || true

echo "🗑 Removing generated data..."
rm -rf openvpn
rm -rf nginx/conf.d nginx/html
rm -f ./*.ovpn
rm -f VPN_CONNECTION_INSTRUCTIONS.txt

echo "✅ Cleanup complete."
