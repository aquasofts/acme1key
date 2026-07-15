#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=../acme1key.sh
source "$ROOT_DIR/acme1key.sh"

valid_domain "example.com"
valid_domain "www.example.com"
valid_domain "xn--fiqs8s.cn"
! valid_domain "example"
! valid_domain "-bad.example.com"
! valid_domain "*.example.com"
! valid_domain "127.0.0.1"

valid_email "admin@example.com"
! valid_email "admin@example"
! valid_email "admin @example.com"

valid_port "1"
valid_port "65535"
! valid_port "0"
! valid_port "65536"
! valid_port "abc"
! (DOMAINS=(); normalize_config) 2>/dev/null

(
    DOMAINS=(" Example.COM. " "www.example.com")
    PORT="8080"
    EMAIL="admin@example.com"
    CERT_DIR=""
    normalize_config
    [[ ${DOMAINS[0]} == "example.com" ]]
    [[ $PRIMARY_DOMAIN == "example.com" ]]
    [[ $CERT_DIR == "/root/cert/example.com" ]]
)

printf 'tests passed\n'
