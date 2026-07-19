#!/usr/bin/env bash
set -euo pipefail

# Install this file as /usr/local/sbin/open-reading-import-release, owned by root
# and allow only the dedicated release mirror SSH user to invoke it with sudo -n.
EXPECTED_CALLER="open-reading-release"
SERVICE_USER="open-reading"
SERVICE_ROOT="/srv/open-reading"

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  echo "This wrapper must run through the restricted sudo rule." >&2
  exit 77
fi
if [[ -z "${SUDO_USER:-}" || "$SUDO_USER" != "$EXPECTED_CALLER" ]]; then
  echo "Caller is not the dedicated release mirror user." >&2
  exit 77
fi

source_dir=""
tag=""
repository=""
manifest="release-manifest.json"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --source) source_dir="${2:-}"; shift 2 ;;
    --tag) tag="${2:-}"; shift 2 ;;
    --repository) repository="${2:-}"; shift 2 ;;
    --manifest) manifest="${2:-}"; shift 2 ;;
    *) echo "Unsupported argument: $1" >&2; exit 64 ;;
  esac
done

if [[ ! "$tag" =~ ^v[0-9]+\.[0-9]+(\.[0-9]+)?([+-][0-9A-Za-z.-]+)?$ ]]; then
  echo "Invalid release tag." >&2
  exit 64
fi
if [[ ! "$repository" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]]; then
  echo "Invalid repository." >&2
  exit 64
fi
if [[ "$manifest" != "$(basename -- "$manifest")" ]]; then
  echo "Manifest must be a plain filename." >&2
  exit 64
fi

source_real="$(realpath -e -- "$source_dir")"
if [[ ! "$source_real" =~ ^/tmp/open-reading-release-[0-9]+-[0-9]+$ ]]; then
  echo "Source directory is outside the approved staging namespace." >&2
  exit 77
fi
if [[ ! -d "$source_real" || "$(stat -c '%U' -- "$source_real")" != "$EXPECTED_CALLER" ]]; then
  echo "Source directory ownership is invalid." >&2
  exit 77
fi
if [[ "$(stat -c '%a' -- "$source_real")" != "700" ]]; then
  echo "Source directory must use mode 0700." >&2
  exit 77
fi
if find "$source_real" -type l -print -quit | grep -q .; then
  echo "Source directory must not contain symbolic links." >&2
  exit 77
fi
if [[ ! -f "$source_real/$manifest" || ! -f "$source_real/SHA256SUMS.txt" ]]; then
  echo "Manifest or checksum file is missing." >&2
  exit 66
fi

cleanup() {
  rm -rf -- "$source_real"
}
trap cleanup EXIT HUP INT TERM

# Remove the upload user's write access before parsing any release metadata.
chown -hR root:root -- "$source_real"
chmod 0700 -- "$source_real"
if find "$source_real" -type l -print -quit | grep -q .; then
  echo "Source directory changed during handoff." >&2
  exit 77
fi
chown -hR "$SERVICE_USER:$SERVICE_USER" -- "$source_real"
find "$source_real" -type d -exec chmod 0700 {} +
find "$source_real" -type f -exec chmod 0600 {} +

runner="$SERVICE_ROOT/current/.venv/bin/python"
importer="$SERVICE_ROOT/current/scripts/import_release.py"
environment_file="$SERVICE_ROOT/shared/.env"
if [[ ! -x "$runner" || ! -f "$importer" || ! -f "$environment_file" ]]; then
  echo "Open Reading release importer is not installed correctly." >&2
  exit 69
fi

set +e
/usr/sbin/runuser -u "$SERVICE_USER" -- /bin/bash -c '
  set -euo pipefail
  set -a
  source "$1"
  set +a
  exec "$2" "$3" --source "$4" --tag "$5" --repository "$6" --manifest "$7"
' bash "$environment_file" "$runner" "$importer" "$source_real" "$tag" "$repository" "$manifest"
status=$?
set -e
exit "$status"
