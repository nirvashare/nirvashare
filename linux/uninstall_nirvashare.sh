#!/usr/bin/env bash
#
# Uninstall NirvaShare: remove its Docker containers, network, (optionally)
# data volumes and images, and clean up /var/nirvashare.
#
#   sudo ./uninstall_nirvashare.sh             # interactive: asks what to remove
#   sudo ./uninstall_nirvashare.sh [options]   # non-interactive, controlled by flags
#
# Options (giving any option skips the interactive questions):
#   --yes             do not ask for confirmation
#   --dry-run         show what would be done, change nothing
#   --keep-data       keep the database volume and /var/nirvashare (only remove containers/network)
#   --remove-images   also remove the Docker images used by the compose file
#   --purge-backups   also remove upgrade backups (pg_upgrade_backup_* folders and
#                     *_pg13_backup_* volumes created by upgrade_pg17.sh)
#   -h, --help        show this help
#
# Based on /var/nirvashare/install-app.yml. Anything else your installer may have
# set up outside Docker (systemd unit, cron job, firewall rules, reverse proxy)
# is NOT removed; the script only warns if it finds a matching systemd unit.

set -euo pipefail

# ----------------------------- CONFIG ---------------------------------------
INSTALL_DIR="${INSTALL_DIR:-/var/nirvashare}"
COMPOSE_FILE="${COMPOSE_FILE:-${INSTALL_DIR}/install-app.yml}"
DB_VOLUME_KEY="db_data"
NETWORK_NAME="nirvashare"            # key under networks: in the compose file
CONTAINERS=(nirvashare_userapp nirvashare_search nirvashare_admin nirvashare_database)
# -----------------------------------------------------------------------------

ASSUME_YES=0; DRY_RUN=0; KEEP_DATA=0; REMOVE_IMAGES=0; PURGE_BACKUPS=0
for arg in "$@"; do
  case "$arg" in
    --yes) ASSUME_YES=1 ;;
    --dry-run) DRY_RUN=1 ;;
    --keep-data) KEEP_DATA=1 ;;
    --remove-images) REMOVE_IMAGES=1 ;;
    --purge-backups) PURGE_BACKUPS=1 ;;
    -h|--help) awk 'NR>1 && /^#/ {sub(/^# ?/,""); print; next} NR>1 {exit}' "$0"; exit 0 ;;
    *) echo "Unknown option: $arg (use --help)" >&2; exit 1 ;;
  esac
done

log()  { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33mWARN: %s\033[0m\n' "$*" >&2; }
die()  { printf '\033[1;31mERROR: %s\033[0m\n' "$*" >&2; exit 1; }
run()  { if [ "$DRY_RUN" = "1" ]; then echo "[dry-run] $*"; else "$@"; fi; }

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

# ----------------------------- PREFLIGHT ------------------------------------
command -v docker >/dev/null || die "docker not found"
# Safety guard for the directory we are about to wipe
INSTALL_DIR="$(realpath -m "$INSTALL_DIR")"
case "$INSTALL_DIR" in
  /|/var|/etc|/usr|/bin|/sbin|/lib|/lib64|/boot|/dev|/proc|/sys|/home|/root|/opt|/tmp|/srv|/mnt|/media|/run)
    die "Refusing to clean '$INSTALL_DIR' (system directory)." ;;
esac
if [ -d "$INSTALL_DIR" ] && [ ! -f "$COMPOSE_FILE" ] && [ ! -f "$INSTALL_DIR/dbpass" ]; then
  die "'$INSTALL_DIR' does not look like a NirvaShare install (no install-app.yml / dbpass). Aborting."
fi

DC="docker compose -f ${COMPOSE_FILE}"

# Collect what exists, before anything is removed
IMAGES=()
if [ -f "$COMPOSE_FILE" ]; then
  while IFS= read -r img; do [ -n "$img" ] && IMAGES+=("$img"); done < <($DC config --images 2>/dev/null | sort -u || true)
fi

DB_VOLUME="$(docker inspect nirvashare_database \
  --format '{{range .Mounts}}{{if eq .Destination "/var/lib/postgresql/data"}}{{.Name}}{{end}}{{end}}' 2>/dev/null || true)"
[ -n "$DB_VOLUME" ] || DB_VOLUME="$(docker volume ls -q | grep -E "^nirvashare_${DB_VOLUME_KEY}\$" | head -n1 || true)"

BACKUP_VOLUMES="$(docker volume ls -q | grep -E "_${DB_VOLUME_KEY}_pg13_backup_" || true)"

# ----------------------------- INTERACTIVE PROMPTS --------------------------
ask_yn() {   # ask_yn "question"  -> returns 0 for yes, 1 for no (default: no)
  local a; read -r -p "$1 [y/N] " a; [[ "$a" =~ ^[Yy]$ ]]
}

check_root

if [ "$#" -eq 0 ] && [ -t 0 ]; then
  HAS_BACKUPS=0
  [ -n "$BACKUP_VOLUMES" ] && HAS_BACKUPS=1
  if ls -d "$INSTALL_DIR"/pg_upgrade_backup_* >/dev/null 2>&1; then HAS_BACKUPS=1; fi

   echo ""
   echo "NirvaShare Uninstall Utility."
   echo ""
   echo "This script will uninstall NirvaShare along with its core services."
   echo "Make sure you have root or sudo access before proceeding."
   echo ""
   echo ""
  
  echo "  1) Full uninstall            (remove containers, database data and $INSTALL_DIR)"
  echo "  2) Remove containers only    (keep database data and $INSTALL_DIR)"
  echo "  3) Preview a full uninstall  (dry run, changes nothing)"
  echo "  4) Quit"
  read -r -p "Choose [1-4]: " choice
  case "$choice" in
    1) ;;
    2) KEEP_DATA=1 ;;
    3) DRY_RUN=1 ;;
    *) terminate; exit 0 ;;
  esac

  if ask_yn "Also remove the Docker images?"; then REMOVE_IMAGES=1; fi
  if [ "$KEEP_DATA" != "1" ] && [ "$HAS_BACKUPS" = "1" ]; then
    if ask_yn "Also remove upgrade backups (pg_upgrade_backup_* folders and *_pg13_backup_* volumes)?"; then
      PURGE_BACKUPS=1
    fi
  fi
  echo
elif [ "$#" -eq 0 ]; then
  die "No options given and no terminal to ask on. Use flags (see --help), e.g. --yes."
fi

if [ "$DRY_RUN" != "1" ] && [ "$(id -u)" -ne 0 ]; then
  die "Run as root (sudo) so /var/nirvashare can be cleaned."
fi

# ----------------------------- SUMMARY + CONFIRM ----------------------------
echo "NirvaShare uninstall plan"
echo "-------------------------"
echo "Containers:        ${CONTAINERS[*]}"
echo "Network:           ${NETWORK_NAME} (project network)"
if [ "$KEEP_DATA" = "1" ]; then
  echo "Database volume:   KEEP (${DB_VOLUME:-none found})"
  echo "Directory:         KEEP ($INSTALL_DIR)"
else
  echo "Database volume:   REMOVE (${DB_VOLUME:-none found})   <-- ALL DATABASE DATA IS DELETED"
  if [ "$PURGE_BACKUPS" = "1" ]; then
    echo "Directory:         REMOVE $INSTALL_DIR completely (including upgrade backups)"
  else
    echo "Directory:         REMOVE contents of $INSTALL_DIR (upgrade backups pg_upgrade_backup_* are kept)"
  fi
fi
if [ -n "$BACKUP_VOLUMES" ]; then
  if [ "$PURGE_BACKUPS" = "1" ]; then echo "Backup volumes:    REMOVE: $(echo $BACKUP_VOLUMES)"
  else echo "Backup volumes:    KEEP:   $(echo $BACKUP_VOLUMES)"; fi
fi
[ "$REMOVE_IMAGES" = "1" ] && echo "Images:            REMOVE: ${IMAGES[*]:-none}" || echo "Images:            keep"
[ "$DRY_RUN" = "1" ] && echo "(dry run: nothing will be changed)"
echo

if [ "$ASSUME_YES" != "1" ] && [ "$DRY_RUN" != "1" ]; then
  if [ "$KEEP_DATA" != "1" ]; then
    read -r -p "Type 'delete nirvashare' to confirm: " ans
    [ "$ans" = "delete nirvashare" ] || die "Aborted."
  else
    read -r -p "Continue? [y/N] " ans
    [[ "$ans" =~ ^[Yy]$ ]] || die "Aborted."
  fi
fi

# ----------------------------- STOP + REMOVE CONTAINERS ---------------------
log "Stopping and removing containers"
if [ -f "$COMPOSE_FILE" ]; then
  if [ "$KEEP_DATA" = "1" ]; then
    run $DC down --remove-orphans
  else
    run $DC down --remove-orphans --volumes
  fi
else
  warn "Compose file not found; removing containers by name"
fi
for c in "${CONTAINERS[@]}"; do
  if docker ps -a --format '{{.Names}}' | grep -qx "$c"; then run docker rm -f "$c"; fi
done

# ----------------------------- VOLUMES --------------------------------------
if [ "$KEEP_DATA" != "1" ]; then
  log "Removing database volume"
  if [ -n "$DB_VOLUME" ] && docker volume inspect "$DB_VOLUME" >/dev/null 2>&1; then
    run docker volume rm "$DB_VOLUME"
  else
    echo "Database volume already gone."
  fi
fi

if [ "$PURGE_BACKUPS" = "1" ] && [ -n "$BACKUP_VOLUMES" ]; then
  log "Removing upgrade backup volumes"
  for v in $BACKUP_VOLUMES; do run docker volume rm "$v"; done
fi

# ----------------------------- NETWORK --------------------------------------
log "Removing network"
for n in $(docker network ls --format '{{.Name}}' | grep -E "^(.*_)?${NETWORK_NAME}\$" || true); do
  run docker network rm "$n" || warn "Could not remove network $n (still in use?)"
done

# ----------------------------- IMAGES ---------------------------------------
if [ "$REMOVE_IMAGES" = "1" ]; then
  log "Removing images"
  for img in "${IMAGES[@]:-}"; do
    [ -n "$img" ] && { run docker rmi "$img" || warn "Could not remove $img (in use by another container?)"; }
  done
fi

# ----------------------------- CLEAN DIRECTORY ------------------------------
if [ "$KEEP_DATA" != "1" ]; then
  log "Cleaning $INSTALL_DIR"
  if [ -d "$INSTALL_DIR" ]; then
    if [ "$PURGE_BACKUPS" = "1" ]; then
      run find "$INSTALL_DIR" -mindepth 1 -delete
      run rmdir "$INSTALL_DIR" 2>/dev/null || true
    else
      run find "$INSTALL_DIR" -mindepth 1 -maxdepth 1 ! -name 'pg_upgrade_backup_*' -exec rm -rf {} +
    fi
  else
    echo "$INSTALL_DIR does not exist."
  fi
fi

# ----------------------------- LEFTOVER HINTS -------------------------------
if command -v systemctl >/dev/null 2>&1; then
  UNITS="$(systemctl list-unit-files 2>/dev/null | grep -i nirvashare || true)"
  [ -n "$UNITS" ] && warn "systemd units mentioning nirvashare were found; remove them manually if they belong to this install:
$UNITS"
fi

log "Done."
[ "$KEEP_DATA" != "1" ] && [ "$PURGE_BACKUPS" != "1" ] && ls -d "$INSTALL_DIR"/pg_upgrade_backup_* >/dev/null 2>&1 \
  && echo "Upgrade backups were kept in $INSTALL_DIR. Re-run with --purge-backups to remove them."
exit 0
