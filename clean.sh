#!/bin/bash
set -e

echo "🧹 Stopping and removing Docker services (OpenVPN + Nginx)..."

if command -v docker compose &> /dev/null; then
    # New plugin style
    docker compose down -v
elif command -v docker-compose &> /dev/null; then
    # Old binary style
    docker-compose down -v
else
    echo "❌ Neither docker compose nor docker-compose found."
    exit 1
fi

echo "🗑 Removing generated OpenVPN configs and certificates..."
rm -rf openvpn

echo "🗑 Removing Nginx configs and html (keeping project base files)..."
rm -rf nginx/conf.d nginx/html

echo "🗑 Removing client ovpn profiles..."
rm -f *.ovpn

echo "✅ Cleanup complete! Project reset to initial state."
