#!/bin/bash
set -e

echo "Usage: $0 add|revoke USERNAME"

ACTION=$1
USERNAME=$2

if [ -z "$ACTION" ] || [ -z "$USERNAME" ]; then
  echo "Usage: $0 add|revoke USERNAME"
  exit 1
fi

if [ "$ACTION" == "add" ]; then
  PASS=$(openssl rand -hex 8)
  echo "$USERNAME:$PASS" >> vpn-users/credentials
  chmod 600 vpn-users/credentials
  docker run -v $(pwd)/openvpn:/etc/openvpn --rm kylemanna/openvpn easyrsa build-client-full $USERNAME nopass || true
  docker run -v $(pwd)/openvpn:/etc/openvpn --rm kylemanna/openvpn ovpn_getclient $USERNAME > ${USERNAME}.ovpn
  echo "User $USERNAME added. Password: $PASS. OVPN file: ${USERNAME}.ovpn"
elif [ "$ACTION" == "revoke" ]; then
  sed -i "/^$USERNAME:/d" vpn-users/credentials
  docker run -v $(pwd)/openvpn:/etc/openvpn --rm kylemanna/openvpn easyrsa revoke $USERNAME
  docker run -v $(pwd)/openvpn:/etc/openvpn --rm kylemanna/openvpn easyrsa gen-crl
  rm -f ${USERNAME}.ovpn
  echo "User $USERNAME revoked."
else
  echo "Invalid action: $ACTION"
fi
