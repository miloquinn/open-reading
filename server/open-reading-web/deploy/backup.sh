#!/usr/bin/env bash
set -euo pipefail

ROOT="${OPEN_READING_ROOT:-/srv/open-reading}"
DATABASE="${OPEN_READING_DATABASE:-$ROOT/data/releases.db}"
BACKUP_DIR="${OPEN_READING_BACKUP_DIR:-$ROOT/backups}"
KEEP_DAYS="${OPEN_READING_BACKUP_KEEP_DAYS:-14}"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
TEMP_DATABASE="$BACKUP_DIR/.releases-$STAMP.tmp.db"
FINAL_DATABASE="$BACKUP_DIR/releases-$STAMP.db"

umask 0077
cleanup() {
  rm -f -- "$TEMP_DATABASE"
}
trap cleanup EXIT HUP INT TERM

install -d -m 0750 "$BACKUP_DIR"
sqlite3 "$DATABASE" ".timeout 10000" ".backup '$TEMP_DATABASE'"
sqlite3 "$TEMP_DATABASE" <<'SQL'
DELETE FROM download_events;
DELETE FROM oauth_states;
DELETE FROM admin_sessions;
UPDATE audit_events SET request_ip = NULL, user_agent = NULL;
VACUUM;
SQL
mv -- "$TEMP_DATABASE" "$FINAL_DATABASE"
gzip -9 "$FINAL_DATABASE"
find "$BACKUP_DIR" -type f -name 'releases-*.db.gz' -mtime "+$KEEP_DAYS" -delete
