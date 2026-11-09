#!/usr/bin/env bash
#
# Upgrade the dockerized PostgreSQL (13 -> 17) for NirvaShare via dump/restore,
# REUSING the existing volume (db_data).
#
#   sudo ./upgrade_pg17.sh            # interactive: asks whether to upgrade or rollback
#   sudo ./upgrade_pg17.sh upgrade    # do the upgrade (no menu)
#   sudo ./upgrade_pg17.sh rollback   # restore PG13 data from the backup volume (no menu)
#
# Because the same volume is reused, the old PG13 files must be removed from it
# before PG17 can initialise. That is only done AFTER:
#   - a verified pg_dumpall of everything, and
#   - a verified copy of the whole old volume into a separate BACKUP VOLUME
#     (<volume>_pg13_backup_<timestamp>), which is never deleted by this script.
# Keep the backup folder until you are happy with the result.
#
# Works even if the compose file already says postgres:17 and the DB container
# is crash-looping: the dump is taken from a temporary PG13 container.

set -euo pipefail

# ----------------------------- CONFIG ---------------------------------------
COMPOSE_FILE="${COMPOSE_FILE:-/var/nirvashare/install-app.yml}"
DB_PASS_FILE="${DB_PASS_FILE:-$(dirname "$COMPOSE_FILE")/dbpass}"
DB_SERVICE="db"
DB_CONTAINER="nirvashare_database"
DB_USER="nirvashare"
OLD_IMAGE="postgres:13"              # temporary dump container / rollback
NEW_IMAGE="postgres:17.11"
VOLUME_KEY="db_data"                 # volume key in the compose file
VOLUME_NAME="${VOLUME_NAME:-}"       # real docker volume name, auto-detected if empty
TMP_CONTAINER="nirvashare_pg13_dump_tmp"
BACKUP_VOLUME=""                     # set later: <volume>_pg13_backup_<timestamp>
BACKUP_DIR="${BACKUP_DIR:-$(dirname "$COMPOSE_FILE")/pg_upgrade_backup_$(date +%Y%m%d_%H%M%S)}"
ASSUME_YES="${ASSUME_YES:-0}"
# -----------------------------------------------------------------------------

DC="docker compose -f ${COMPOSE_FILE}"

log()  { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33mWARN: %s\033[0m\n' "$*" >&2; }
die()  { printf '\033[1;31mERROR: %s\033[0m\n' "$*" >&2; exit 1; }

terminate()
{
    echo ""
    echo "Installation terminated"
    exit 0
}

check_root() {

	if [ "$(id -u)" -ne 0 ]; then
	  echo "Error: This script must be run as root."
	 terminate; exit;
	fi
}


# ----------------------------- ACTION SELECTION -----------------------------
check_root

MODE="${1:-}"
case "$MODE" in
  upgrade|rollback) ;;
  "")
    [ -t 0 ] || die "No action given and no terminal to ask on. Usage: $0 [upgrade|rollback]"
   echo ""
   echo "NirvaShare Database Upgrade Utility."
   echo ""
   echo "This script will upgrade NirvaShare database."
   echo "Make sure you have root or sudo access before proceeding."
   echo ""
   echo ""
   
    
    echo "  1) Upgrade PostgreSQL 13.2 -> 17.11"
    echo "  2) Rollback to PostgreSQL 13 (from the latest backup)"
    echo "  3) Quit"
    echo ""
    read -r -p "Choose [1-3]: " choice
    case "$choice" in
      1|upgrade)  MODE=upgrade ;;
      2|rollback) MODE=rollback ;;
      *) terminate; exit 0 ;;
    esac
    ;;
  *) die "Unknown action '$MODE'. Usage: $0 [upgrade|rollback]" ;;
esac

cleanup() { docker rm -f "$TMP_CONTAINER" >/dev/null 2>&1 || true; }
trap cleanup EXIT

detect_volume() {
  if [ -z "$VOLUME_NAME" ]; then
    VOLUME_NAME="$(docker inspect "$DB_CONTAINER" \
      --format '{{range .Mounts}}{{if eq .Destination "/var/lib/postgresql/data"}}{{.Name}}{{end}}{{end}}' 2>/dev/null || true)"
  fi
  if [ -z "$VOLUME_NAME" ]; then
    VOLUME_NAME="$(docker volume ls -q | grep -E "_${VOLUME_KEY}\$" | head -n1 || true)"
  fi
  [ -n "$VOLUME_NAME" ] || die "Could not detect the data volume. Run 'docker volume ls' and pass VOLUME_NAME=..."
  docker volume inspect "$VOLUME_NAME" >/dev/null 2>&1 || die "Volume '$VOLUME_NAME' does not exist"
}

wipe_volume() {
  docker run --rm -v "${VOLUME_NAME}:/data" alpine sh -c 'find /data -mindepth 1 -delete'
}

wait_for_db() {
  # TCP check (-h 127.0.0.1): the temporary server used during first-time init
  # only listens on the unix socket, so this avoids a false "ready".
  local tries=90
  until docker exec "$DB_CONTAINER" pg_isready -h 127.0.0.1 -U "$DB_USER" >/dev/null 2>&1; do
    tries=$((tries - 1))
    [ "$tries" -gt 0 ] || die "Database not ready in time. Check: docker logs $DB_CONTAINER"
    sleep 2
  done
}

# ----------------------------- ROLLBACK -------------------------------------
if [ "$MODE" = "rollback" ]; then
  latest="$(ls -1d "$(dirname "$COMPOSE_FILE")"/pg_upgrade_backup_*/ 2>/dev/null | sort | tail -n1 || true)"
  [ -n "$latest" ] || die "No pg_upgrade_backup_* directory found."
  [ -f "${latest}backup_volume_name.txt" ] || die "No backup_volume_name.txt in $latest"
  [ -f "${latest}compose.original.yml" ] || die "No compose backup in $latest"
  BACKUP_VOLUME="$(cat "${latest}backup_volume_name.txt")"
  docker volume inspect "$BACKUP_VOLUME" >/dev/null 2>&1 || die "Backup volume '$BACKUP_VOLUME' not found"
  detect_volume

  echo "Rollback will ERASE volume '$VOLUME_NAME' and copy PG13 files back from volume '$BACKUP_VOLUME'."
  if [ "$ASSUME_YES" != "1" ]; then
    read -r -p "Continue? [y/N] " ans
    [[ "$ans" =~ ^[Yy]$ ]] || die "Aborted."
  fi

  log "Stopping the stack"
  $DC down
  log "Restoring PG13 data into the volume"
  wipe_volume
  docker run --rm \
    -v "${BACKUP_VOLUME}:/from:ro" \
    -v "${VOLUME_NAME}:/to" \
    alpine sh -c 'cp -a /from/. /to/'

  log "Restoring compose file with $OLD_IMAGE"
  cat "${latest}compose.original.yml" > "$COMPOSE_FILE"
  sed -E "s#(image:[[:space:]]*['\"]?)postgres:[0-9][0-9.]*#\1${OLD_IMAGE}#" "$COMPOSE_FILE" > "${COMPOSE_FILE}.tmp"
  cat "${COMPOSE_FILE}.tmp" > "$COMPOSE_FILE"; rm -f "${COMPOSE_FILE}.tmp"
  $DC up -d
  log "Rolled back to PG13. Backup volume '$BACKUP_VOLUME' was kept."
  exit 0
fi

# ----------------------------- PREFLIGHT ------------------------------------
log "Preflight checks"
command -v docker >/dev/null || die "docker not found"
docker compose version >/dev/null 2>&1 || die "'docker compose' plugin not found"
[ -f "$COMPOSE_FILE" ] || die "Compose file not found: $COMPOSE_FILE"
[ -f "$DB_PASS_FILE" ] || die "Password file not found: $DB_PASS_FILE (set DB_PASS_FILE=...)"
grep -qE "${VOLUME_KEY}:/var/lib/postgresql/data" "$COMPOSE_FILE" \
  || die "Compose file does not mount '${VOLUME_KEY}' at /var/lib/postgresql/data"

detect_volume
echo "Data volume: $VOLUME_NAME"

PGVER="$(docker run --rm -v "${VOLUME_NAME}:/data:ro" alpine cat /data/PG_VERSION 2>/dev/null || true)"
echo "Data directory is PostgreSQL major version: ${PGVER:-unknown}"
case "$PGVER" in
  13) ;;
  17) die "Volume already contains PG17 data. Nothing to upgrade." ;;
  *)  die "Expected PG13 data in $VOLUME_NAME, found '${PGVER:-nothing}'. Aborting." ;;
esac

if [ "$ASSUME_YES" != "1" ]; then
  echo
  echo "This will stop the whole NirvaShare stack, dump the DB, back up the volume,"
  echo "then ERASE the old files in '$VOLUME_NAME' and restore into a fresh PG17 cluster."
  echo "A copy of the old data is kept in a new Docker volume: ${VOLUME_NAME}_pg13_backup_<timestamp>"
  read -r -p "Continue? [y/N] " ans
  [[ "$ans" =~ ^[Yy]$ ]] || die "Aborted."
fi

mkdir -p "$BACKUP_DIR"
log "Backups will be stored in: $BACKUP_DIR"

# ----------------------------- STOP STACK -----------------------------------
log "Stopping the stack (also ends any PG17 crash loop; data is untouched)"
$DC down

# ----------------------------- DUMP FROM TEMP PG13 --------------------------
log "Starting a temporary $OLD_IMAGE container on the volume"
docker rm -f "$TMP_CONTAINER" >/dev/null 2>&1 || true
docker run -d --name "$TMP_CONTAINER" \
  -v "${VOLUME_NAME}:/var/lib/postgresql/data" \
  "$OLD_IMAGE" >/dev/null

tries=60
until docker exec "$TMP_CONTAINER" pg_isready -U "$DB_USER" >/dev/null 2>&1; do
  tries=$((tries - 1))
  [ "$tries" -gt 0 ] || { docker logs "$TMP_CONTAINER" | tail -n 30; die "Temporary PG13 did not start."; }
  sleep 2
done
echo "Server version: $(docker exec "$TMP_CONTAINER" psql -U "$DB_USER" -d postgres -Atc 'SHOW server_version;')"

DUMP_FILE="$BACKUP_DIR/backup_pg13.sql"
log "Running pg_dumpall"
docker exec "$TMP_CONTAINER" pg_dumpall -U "$DB_USER" > "$DUMP_FILE"
[ -s "$DUMP_FILE" ] || die "Dump file is empty!"
tail -n 5 "$DUMP_FILE" | grep -q "PostgreSQL database cluster dump complete" \
  || die "Dump looks incomplete. Aborting; nothing has been changed."
echo "Dump OK: $(du -h "$DUMP_FILE" | cut -f1)  ->  $DUMP_FILE"

log "Stopping temporary PG13 cleanly"
docker stop -t 120 "$TMP_CONTAINER" >/dev/null
docker rm "$TMP_CONTAINER" >/dev/null

# ----------------------------- BACKUP VOLUME (mandatory) --------------------
BACKUP_VOLUME="${VOLUME_NAME}_pg13_backup_$(date +%Y%m%d_%H%M%S)"
log "Copying the whole old volume into backup volume '$BACKUP_VOLUME' (this is your rollback)"
docker volume create "$BACKUP_VOLUME" >/dev/null
echo "$BACKUP_VOLUME" > "$BACKUP_DIR/backup_volume_name.txt"
docker run --rm \
  -v "${VOLUME_NAME}:/from:ro" \
  -v "${BACKUP_VOLUME}:/to" \
  alpine sh -c 'cp -a /from/. /to/'

SRC_COUNT="$(docker run --rm -v "${VOLUME_NAME}:/v:ro" alpine sh -c 'find /v | wc -l')"
DST_COUNT="$(docker run --rm -v "${BACKUP_VOLUME}:/v:ro" alpine sh -c 'find /v | wc -l')"
[ "$SRC_COUNT" = "$DST_COUNT" ] && [ "$DST_COUNT" -gt 1 ] \
  || die "Backup volume verification failed (source $SRC_COUNT entries, backup $DST_COUNT). Nothing has been changed."
docker run --rm -v "${BACKUP_VOLUME}:/v:ro" alpine test -f /v/PG_VERSION \
  || die "Backup volume has no PG_VERSION. Nothing has been changed."
echo "Backup volume verified ($DST_COUNT entries)."

# ----------------------------- EDIT COMPOSE (image only) --------------------
log "Setting image to $NEW_IMAGE in $COMPOSE_FILE"
cp "$COMPOSE_FILE" "$BACKUP_DIR/compose.original.yml"
sed -E "s#(image:[[:space:]]*['\"]?)postgres:[0-9][0-9.]*#\1${NEW_IMAGE}#" "$COMPOSE_FILE" > "${COMPOSE_FILE}.tmp"
grep -q "$NEW_IMAGE" "${COMPOSE_FILE}.tmp" || { rm -f "${COMPOSE_FILE}.tmp"; die "Could not set image tag automatically; edit the compose file manually."; }
cat "${COMPOSE_FILE}.tmp" > "$COMPOSE_FILE"; rm -f "${COMPOSE_FILE}.tmp"
diff -u "$BACKUP_DIR/compose.original.yml" "$COMPOSE_FILE" || true
$DC config >/dev/null || { cat "$BACKUP_DIR/compose.original.yml" > "$COMPOSE_FILE"; die "New compose invalid; original restored."; }

# ----------------------------- WIPE VOLUME + START PG17 ---------------------
log "Erasing old PG13 files from '$VOLUME_NAME' (copied to '$BACKUP_VOLUME' and verified above)"
wipe_volume

log "Starting PostgreSQL 17 (fresh cluster in the same volume)"
$DC up -d "$DB_SERVICE"
wait_for_db
NEW_VERSION="$(docker exec "$DB_CONTAINER" psql -U "$DB_USER" -d postgres -Atc 'SHOW server_version;')"
echo "New server version: $NEW_VERSION"
case "$NEW_VERSION" in 17*) ;; *) die "Expected PG17, got $NEW_VERSION" ;; esac

# ----------------------------- RESTORE --------------------------------------
log "Restoring dump"
docker exec -i "$DB_CONTAINER" psql -U "$DB_USER" -d postgres \
  < "$DUMP_FILE" > "$BACKUP_DIR/restore_output.log" 2> "$BACKUP_DIR/restore_errors.log" || true
REAL_ERRORS="$(grep -i 'error' "$BACKUP_DIR/restore_errors.log" | grep -vi 'already exists' || true)"
if [ -n "$REAL_ERRORS" ]; then
  warn "Unexpected restore errors:"; echo "$REAL_ERRORS" | head -n 20
  warn "Full log: $BACKUP_DIR/restore_errors.log"
else
  echo "Restore finished with no unexpected errors."
fi

# PG13 stored the password as an md5 hash; PG17's default pg_hba requires
# scram-sha-256 for network logins. Re-set the password from the secret file
# so it is stored as SCRAM.
log "Re-setting the '$DB_USER' password as SCRAM from $DB_PASS_FILE"
DB_PASS="$(cat "$DB_PASS_FILE")"
printf "ALTER ROLE %s PASSWORD :'pw';\n" "$DB_USER" | \
  docker exec -i -e PW="$DB_PASS" "$DB_CONTAINER" \
  sh -c "psql -U '$DB_USER' -d postgres -v ON_ERROR_STOP=1 -v pw=\"\$PW\""
unset DB_PASS

log "Running ANALYZE on all databases"
for db in $(docker exec "$DB_CONTAINER" psql -U "$DB_USER" -d postgres -Atc \
            "SELECT datname FROM pg_database WHERE datallowconn AND NOT datistemplate;"); do
  docker exec "$DB_CONTAINER" psql -U "$DB_USER" -d "$db" -qc 'ANALYZE;'
  echo "  analyzed: $db"
done

log "Databases present:"
docker exec "$DB_CONTAINER" psql -U "$DB_USER" -d postgres -c '\l'

log "Testing a password (TCP) login, as the apps will do"
docker exec -e PGPASSWORD="$(cat "$DB_PASS_FILE")" "$DB_CONTAINER" \
  psql -h 127.0.0.1 -U "$DB_USER" -d postgres -Atc 'SELECT 1;' >/dev/null \
  && echo "Password login OK" || warn "Password login FAILED, check before relying on the apps"

# ----------------------------- START REST -----------------------------------
log "Starting the rest of the stack"
$DC up -d

cat <<EOF

Done. PostgreSQL is now $NEW_VERSION, running on the same volume '$VOLUME_NAME'.

  - Test your application (admin & userapp).
  - Backups (keep until satisfied):
      volume  $BACKUP_VOLUME   full copy of the old PG13 data
      file    $BACKUP_DIR/backup_pg13.sql   logical dump

# Rollback:       sudo ./upgrade_pg17.sh rollback
Later cleanup:  docker volume rm $BACKUP_VOLUME
EOF
