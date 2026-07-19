#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${1:-https://open.xxread.top}"

curl --fail --silent --show-error "$BASE_URL/api/health" >/dev/null
curl --fail --silent --show-error "$BASE_URL/" >/dev/null
curl --fail --silent --show-error "$BASE_URL/download" >/dev/null

headers="$(curl --fail --silent --show-error --dump-header - --output /dev/null "$BASE_URL/")"
grep -qi '^strict-transport-security:' <<<"$headers"
grep -qi '^x-content-type-options: nosniff' <<<"$headers"

status="$(curl --silent --output /dev/null --write-out '%{http_code}' "$BASE_URL/.env")"
[[ "$status" == "403" || "$status" == "404" ]]

printf 'Production checks passed for %s\n' "$BASE_URL"
