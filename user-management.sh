#!/usr/bin/env bash
set -Eeuo pipefail

ACTION="${1:-}"
USERNAME="${2:-}"

usage() {
  echo "Usage:"
  echo "  $0 add USERNAME"
  echo "  $0 revoke USERNAME"
  echo "  $0 list"
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "❌ Required command not found: $1"
    exit 1
  }
}

require_cmd docker

[[ -n "$ACTION" ]] || usage

case "$ACTION" in
  add)
    [[ -n "$USERNAME" ]] || usage

    if [[ -f "${USERNAME}.ovpn" ]]; then
      echo "❌ ${USERNAME}.ovpn already exists."
      exit 1
    fi

    docker run --rm \
      -v "$(pwd)/openvpn:/etc/openvpn" \
      kylemanna/openvpn \
      easyrsa build-client-full "${USERNAME}" nopass

    docker run --rm \
      -v "$(pwd)/openvpn:/etc/openvpn" \
      kylemanna/openvpn \
      ovpn_getclient "${USERNAME}" > "${USERNAME}.ovpn"

    echo "✅ User ${USERNAME} added"
    echo "📄 Profile: ${USERNAME}.ovpn"
    ;;

  revoke)
    [[ -n "$USERNAME" ]] || usage

    docker run --rm \
      -v "$(pwd)/openvpn:/etc/openvpn" \
      kylemanna/openvpn \
      easyrsa revoke "${USERNAME}"

    docker run --rm \
      -v "$(pwd)/openvpn:/etc/openvpn" \
      kylemanna/openvpn \
      easyrsa gen-crl

    rm -f "${USERNAME}.ovpn"

    docker compose restart openvpn

    echo "✅ User ${USERNAME} revoked"
    ;;

  list)
    if [[ -d openvpn/pki/issued ]]; then
      echo "Issued client certificates:"
      ls -1 openvpn/pki/issued | sed 's/\.crt$//' | sort
    else
      echo "No PKI found."
    fi
    ;;

  *)
    usage
    ;;
esac
