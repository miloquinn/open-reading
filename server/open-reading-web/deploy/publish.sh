#!/usr/bin/env bash
set -euo pipefail

: "${DEPLOY_HOST:?Set DEPLOY_HOST to the deployment host name}"
: "${DEPLOY_USER:?Set DEPLOY_USER to the dedicated deployment user}"
DEPLOY_ROOT="${DEPLOY_ROOT:-/srv/open-reading}"
HEALTH_URL="${HEALTH_URL:-https://open.xxread.top/api/health}"
RELEASE_ID="$(date -u +%Y%m%dT%H%M%SZ)"
REMOTE_RELEASE="$DEPLOY_ROOT/code-releases/$RELEASE_ID"
PYTHON_BIN="${PYTHON_BIN:-.venv/bin/python}"
DEPLOY_IDENTITY_FILE="${DEPLOY_IDENTITY_FILE:-}"
REQUIRED_UV_VERSION="0.11.8"

ssh_args=("-o" "BatchMode=yes")
if [[ -n "$DEPLOY_IDENTITY_FILE" ]]; then
  ssh_args+=("-i" "$DEPLOY_IDENTITY_FILE")
fi
rsync_ssh="ssh"
for item in "${ssh_args[@]}"; do
  printf -v quoted '%q' "$item"
  rsync_ssh+=" $quoted"
done

"$PYTHON_BIN" -m pytest
"$PYTHON_BIN" -m ruff check app tests scripts

ssh "${ssh_args[@]}" "$DEPLOY_USER@$DEPLOY_HOST" "mkdir -p '$REMOTE_RELEASE' '$DEPLOY_ROOT/code-releases' '$DEPLOY_ROOT/shared' '$DEPLOY_ROOT/data' '$DEPLOY_ROOT/releases' '$DEPLOY_ROOT/backups'"
rsync -az --delete -e "$rsync_ssh" \
  --exclude '.env' \
  --exclude '.env.*' \
  --exclude '.venv*' \
  --exclude '__pycache__' \
  --exclude '.pytest_cache' \
  --exclude '.ruff_cache' \
  --exclude '.DS_Store' \
  --exclude '.playwright-cli' \
  --exclude 'output' \
  --exclude 'data/' \
  --exclude 'releases/' \
  --exclude 'storage/' \
  --exclude 'backups/' \
  --exclude 'logs/' \
  --exclude '.incoming/' \
  --exclude '*.db' \
  --exclude '*.db-*' \
  --exclude '*.sqlite' \
  --exclude '*.sqlite3' \
  --exclude '*.key' \
  --exclude '*.pem' \
  --exclude '*.jks' \
  --exclude '*.keystore' \
  --exclude '*.p12' \
  --exclude '*.pfx' \
  --exclude 'id_rsa*' \
  --exclude 'id_ed25519*' \
  ./ "$DEPLOY_USER@$DEPLOY_HOST:$REMOTE_RELEASE/"

ssh "${ssh_args[@]}" "$DEPLOY_USER@$DEPLOY_HOST" bash -s -- \
  "$DEPLOY_ROOT" "$REMOTE_RELEASE" "$REQUIRED_UV_VERSION" <<'REMOTE'
set -euo pipefail
deploy_root="$1"
remote_release="$2"
required_uv_version="$3"
previous="$(readlink -f "$deploy_root/current" 2>/dev/null || true)"

uv_bin="$(command -v uv || true)"
if [[ -z "$uv_bin" ]]; then
  echo "Required uv $required_uv_version is not installed on the deployment host." >&2
  exit 69
fi
read -r uv_name installed_uv_version _ < <("$uv_bin" --version)
if [[ "$uv_name" != "uv" || "$installed_uv_version" != "$required_uv_version" ]]; then
  echo "Deployment host must use uv $required_uv_version; found: $uv_name $installed_uv_version" >&2
  exit 69
fi

cd "$remote_release"
"$uv_bin" lock --check
UV_PROJECT_ENVIRONMENT="$remote_release/.venv" \
  "$uv_bin" sync --frozen --no-dev --python python3.12
ln -sfn "$remote_release" "$deploy_root/current"

if ! sudo systemctl restart open-reading-web.service; then
  if [[ -n "$previous" ]]; then ln -sfn "$previous" "$deploy_root/current"; fi
  sudo systemctl restart open-reading-web.service || true
  exit 1
fi

for _ in {1..20}; do
  if curl --fail --silent http://127.0.0.1:3002/api/health >/dev/null; then exit 0; fi
  sleep 1
done

if [[ -n "$previous" ]]; then ln -sfn "$previous" "$deploy_root/current"; fi
sudo systemctl restart open-reading-web.service || true
exit 1
REMOTE

curl --fail --silent --show-error "$HEALTH_URL" >/dev/null
printf 'Published %s and verified %s\n' "$RELEASE_ID" "$HEALTH_URL"
