#!/bin/bash
set -e

echo "🧹 Stopping and removing Docker services..."

if command -v docker compose &> /dev/null; then
    docker compose down -v
elif command -v docker-compose &> /dev/null; then
    docker-compose down -v
else
    echo "❌ Docker not found."
    exit 1
fi

echo "🗑 Removing OpenVPN configs and certificates..."
rm -rf openvpn vpn-users
echo "🗑 Removing Nginx configs and html..."
rm -rf nginx/conf.d nginx/html
echo "🗑 Removing client ovpn files..."
rm -f *.ovpn

echo "✅ Cleanup complete."
