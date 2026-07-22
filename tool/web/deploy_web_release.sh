#!/usr/bin/env bash
# Install as /usr/local/sbin/open-reading-deploy-web, owned by root:root, mode 0750.

set -euo pipefail

readonly DEPLOY_USER="open-reading-release"
readonly DEPLOY_ROOT="/srv/open-reading/flutter-web"
readonly RELEASES_ROOT="${DEPLOY_ROOT}/releases"
readonly CURRENT_LINK="${DEPLOY_ROOT}/current"
readonly ARCHIVE_NAME="open-reading-web.tar.gz"
readonly CHECKSUM_NAME="${ARCHIVE_NAME}.sha256"
readonly RETAIN_RELEASES=5

die() {
  printf 'open-reading-deploy-web: %s\n' "$*" >&2
  exit 1
}

usage() {
  cat >&2 <<'EOF'
Usage: open-reading-deploy-web \
  --source /tmp/open-reading-web-RUN_ID-RUN_ATTEMPT \
  --tag vX.Y.Z \
  --repository OWNER/REPOSITORY \
  --run-id RUN_ID \
  --run-attempt RUN_ATTEMPT
EOF
  exit 2
}

[[ "$EUID" -eq 0 ]] || die "must run as root"
[[ "${SUDO_USER:-}" == "$DEPLOY_USER" ]] \
  || die "must be invoked through sudo by ${DEPLOY_USER}"

source_dir=""
tag=""
repository=""
run_id=""
run_attempt=""
while (("$#" > 0)); do
  case "$1" in
    --source)
      [[ "$#" -ge 2 ]] || usage
      source_dir="$2"
      shift 2
      ;;
    --tag)
      [[ "$#" -ge 2 ]] || usage
      tag="$2"
      shift 2
      ;;
    --repository)
      [[ "$#" -ge 2 ]] || usage
      repository="$2"
      shift 2
      ;;
    --run-id)
      [[ "$#" -ge 2 ]] || usage
      run_id="$2"
      shift 2
      ;;
    --run-attempt)
      [[ "$#" -ge 2 ]] || usage
      run_attempt="$2"
      shift 2
      ;;
    *)
      usage
      ;;
  esac
done

[[ "$tag" =~ ^v[0-9A-Za-z][0-9A-Za-z._-]{0,63}$ ]] \
  || die "invalid release tag"
[[ "$repository" =~ ^[0-9A-Za-z_.-]+/[0-9A-Za-z_.-]+$ ]] \
  || die "invalid repository"
[[ "$run_id" =~ ^[0-9]+$ ]] || die "invalid GitHub run ID"
[[ "$run_attempt" =~ ^[0-9]+$ ]] || die "invalid GitHub run attempt"

expected_source="/tmp/open-reading-web-${run_id}-${run_attempt}"
[[ "$source_dir" == "$expected_source" ]] \
  || die "source is outside the permitted staging namespace"
[[ -d "$source_dir" && ! -L "$source_dir" ]] || die "source is not a directory"
[[ "$(readlink -f -- "$source_dir")" == "$expected_source" ]] \
  || die "source path contains a symlink"
[[ "$(stat -c '%U' -- "$source_dir")" == "$DEPLOY_USER" ]] \
  || die "source has the wrong owner"
[[ "$(stat -c '%a' -- "$source_dir")" == "700" ]] \
  || die "source must have mode 0700"

staged_archive_path="${source_dir}/${ARCHIVE_NAME}"
staged_checksum_path="${source_dir}/${CHECKSUM_NAME}"
mapfile -t staged_entries < <(find "$source_dir" -mindepth 1 -maxdepth 1 -printf '%f\n' | LC_ALL=C sort)
expected_entries=("$ARCHIVE_NAME" "$CHECKSUM_NAME")
if [[ "${staged_entries[*]}" != "${expected_entries[*]}" ]]; then
  die "source must contain only the web archive and its checksum"
fi

for staged_file in "$staged_archive_path" "$staged_checksum_path"; do
  [[ -f "$staged_file" && ! -L "$staged_file" ]] \
    || die "staged input is not a regular file: $(basename "$staged_file")"
  [[ "$(stat -c '%U' -- "$staged_file")" == "$DEPLOY_USER" ]] \
    || die "staged input has the wrong owner: $(basename "$staged_file")"
  file_mode="$((8#$(stat -c '%a' -- "$staged_file")))"
  (( (file_mode & 8#022) == 0 )) \
    || die "staged input is group- or world-writable: $(basename "$staged_file")"
done

mkdir -p -- "$RELEASES_ROOT"
chmod 0755 -- "$DEPLOY_ROOT" "$RELEASES_ROOT"
work_dir="$(mktemp -d "${DEPLOY_ROOT}/.deploy-${run_id}-${run_attempt}.XXXXXX")"
incoming_dir=""
cleanup_work() {
  if [[ -n "$incoming_dir" ]]; then
    rm -rf -- "$incoming_dir"
  fi
  rm -rf -- "$work_dir"
}
trap cleanup_work EXIT

archive_path="${work_dir}/${ARCHIVE_NAME}"
checksum_path="${work_dir}/${CHECKSUM_NAME}"
EXPECTED_DEPLOY_USER="$DEPLOY_USER" python3 - \
  "$staged_archive_path" "$archive_path" \
  "$staged_checksum_path" "$checksum_path" <<'PY'
import os
import pwd
import shutil
import stat
import sys

expected_uid = pwd.getpwnam(os.environ["EXPECTED_DEPLOY_USER"]).pw_uid
for source, destination in zip(sys.argv[1::2], sys.argv[2::2]):
    source_fd = os.open(source, os.O_RDONLY | os.O_NOFOLLOW)
    try:
        metadata = os.fstat(source_fd)
        if not stat.S_ISREG(metadata.st_mode):
            raise SystemExit(f"staged input is not a regular file: {source}")
        if metadata.st_uid != expected_uid or metadata.st_mode & 0o022:
            raise SystemExit(f"staged input ownership or mode is unsafe: {source}")
        destination_fd = os.open(
            destination,
            os.O_WRONLY | os.O_CREAT | os.O_EXCL,
            0o600,
        )
        try:
            with os.fdopen(os.dup(source_fd), "rb") as source_file:
                with os.fdopen(os.dup(destination_fd), "wb") as destination_file:
                    shutil.copyfileobj(source_file, destination_file)
        finally:
            os.close(destination_fd)
    finally:
        os.close(source_fd)
PY

checksum_line="$(cat -- "$checksum_path")"
[[ "$checksum_line" =~ ^([0-9a-fA-F]{64})[[:space:]][[:space:]]open-reading-web\.tar\.gz$ ]] \
  || die "checksum file has an invalid format"
archive_sha256="${BASH_REMATCH[1],,}"
(
  cd "$work_dir"
  sha256sum --check --strict "$CHECKSUM_NAME"
) >/dev/null || die "archive checksum verification failed"

python3 - "$archive_path" <<'PY'
from __future__ import annotations

import pathlib
import sys
import tarfile

archive = pathlib.Path(sys.argv[1])
seen: set[str] = set()
with tarfile.open(archive, mode="r:gz") as bundle:
    members = bundle.getmembers()
    if not members:
        raise SystemExit("web archive is empty")
    for member in members:
        name = member.name
        if "\\" in name or any(ord(character) < 32 for character in name):
            raise SystemExit(f"unsafe archive entry name: {name!r}")
        path = pathlib.PurePosixPath(name)
        if path.is_absolute() or ".." in path.parts:
            raise SystemExit(f"unsafe archive entry path: {name!r}")
        normalized = str(path)
        if normalized in seen:
            raise SystemExit(f"duplicate archive entry: {name!r}")
        seen.add(normalized)
        if not (member.isdir() or member.isfile()):
            raise SystemExit(f"unsupported archive entry type: {name!r}")
PY

release_id="${tag}-${run_id}-${run_attempt}-${archive_sha256:0:12}"
release_dir="${RELEASES_ROOT}/${release_id}"
[[ ! -L "$release_dir" ]] || die "release path is a symlink"

if [[ ! -d "$release_dir" ]]; then
  incoming_dir="$(mktemp -d "${RELEASES_ROOT}/.incoming-${release_id}.XXXXXX")"

  tar \
    --extract \
    --gzip \
    --file "$archive_path" \
    --directory "$incoming_dir" \
    --no-same-owner \
    --no-same-permissions

  [[ -f "${incoming_dir}/version.json" && ! -L "${incoming_dir}/version.json" ]] \
    || die "archive does not contain version.json at its root"
  VERSION_PATH="${incoming_dir}/version.json" RELEASE_TAG="$tag" python3 <<'PY'
import json
import os
from pathlib import Path

payload = json.loads(Path(os.environ["VERSION_PATH"]).read_text(encoding="utf-8"))
expected = os.environ["RELEASE_TAG"].removeprefix("v")
if payload.get("version") != expected:
    raise SystemExit("version.json does not match the release tag")
PY

  chown -R root:root -- "$incoming_dir"
  find "$incoming_dir" -type d -exec chmod 0755 {} +
  find "$incoming_dir" -type f -exec chmod 0644 {} +
  mv -- "$incoming_dir" "$release_dir"
  incoming_dir=""
fi

[[ -f "${release_dir}/version.json" && ! -L "${release_dir}/version.json" ]] \
  || die "release directory is incomplete"
VERSION_PATH="${release_dir}/version.json" RELEASE_TAG="$tag" python3 <<'PY'
import json
import os
from pathlib import Path

payload = json.loads(Path(os.environ["VERSION_PATH"]).read_text(encoding="utf-8"))
if payload.get("version") != os.environ["RELEASE_TAG"].removeprefix("v"):
    raise SystemExit("release directory version does not match the release tag")
PY

temporary_link="${DEPLOY_ROOT}/.current-${run_id}-${run_attempt}-$$"
ln -s -- "releases/${release_id}" "$temporary_link"
mv -Tf -- "$temporary_link" "$CURRENT_LINK"

mapfile -t releases_by_age < <(
  find "$RELEASES_ROOT" -mindepth 1 -maxdepth 1 -type d ! -name '.incoming-*' \
    -printf '%T@ %f\n' | LC_ALL=C sort -nr | cut -d ' ' -f 2-
)
for ((index = RETAIN_RELEASES; index < ${#releases_by_age[@]}; index++)); do
  old_release="${releases_by_age[$index]}"
  [[ "$old_release" == "$release_id" ]] && continue
  [[ "$old_release" =~ ^v[0-9A-Za-z][0-9A-Za-z._-]{0,63}-[0-9]+-[0-9]+-[0-9a-f]{12}$ ]] \
    || die "refusing to remove an unexpected release directory"
  rm -rf -- "${RELEASES_ROOT:?}/${old_release}"
done

printf 'Deployed %s from %s (%s, run %s attempt %s).\n' \
  "$tag" "$repository" "$archive_sha256" "$run_id" "$run_attempt"
