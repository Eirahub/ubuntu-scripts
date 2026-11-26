#!/usr/bin/env bash
# Kjører modulene i config.sh. Startes av systemd ved oppstart og hver 6. time.
#
#   sudo ./run.sh                 alt: oppdater repoet, root-delene, så brukerdelene for hver bruker
#   sudo ./run.sh --modul NAVN    bare én modul (også om den er slått av i config)
#   ./run.sh --bruker             bare brukerdelene for deg (kalles av root-kjøringen)
#   sudo ./run.sh --tidlig        før innloggingsskjermen, uten nett: early_root_part, så early_user_part per bruker
#   sudo ./run.sh --nullstill     nullstill elevbrukeren ved neste oppstart
#   ./run.sh --status             vis moduler og innstillinger
#   sudo ./run.sh --avinstaller   rydd etter alle moduler som kan det (kalles av install.sh)
set -euo pipefail

KK_DIR=$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)
LOGFILE="/var/log/ubuntu-scripts.log"

# shellcheck source=lib/common.sh
source "$KK_DIR/lib/common.sh"

load_config() {
  # shellcheck source=config.sh
  source "$KK_DIR/config.sh"
  # Lokal config kan ha passord og er bare lesbar for root; brukerdelene trenger den ikke
  if [ -r /etc/ubuntu-scripts/config.local.sh ]; then source /etc/ubuntu-scripts/config.local.sh; fi
}
load_config

KK_TMP=$(mktemp -d)
trap 'rm -rf "$KK_TMP"' EXIT
export KK_TMP

# run_part <funksjon> <modul>  kjører én del av én modul i et eget skall, så en feil ikke stopper resten
run_part() {
  local part=$1 m=$2 f="$KK_DIR/modules/$2.sh" rc
  [ -f "$f" ] || { log "Fant ikke modulen $m (modules/$m.sh)."; return 0; }
  set +e
  (
    set -e
    MODULE=$m
    source "$f"
    if declare -F "$part" >/dev/null; then "$part"; fi
  )
  rc=$?
  set -e
  [ "$rc" = 0 ] || log "Modulen $m feilet i $part (kode $rc)."
}

all_modules() { for f in "$KK_DIR"/modules/*.sh; do basename "$f" .sh; done; }

disabled_modules() {
  local m
  for m in $(all_modules); do
    [[ " $MODULES " == *" $m "* ]] || echo "$m"
  done
}

self_update() {  # henter siste versjon av repoet og starter den nye run.sh hvis noe er endret
  [ "${KK_UPDATED:-}" = 1 ] && return 0
  [ -n "${REPO_TARBALL:-}" ] && [ -w "$(dirname "$KK_DIR")" ] || return 0
  local work new f
  work=$(mktemp -d "$(dirname "$KK_DIR")/.ubuntu-scripts-update.XXXXXX")
  new="$work/new"
  mkdir -p "$new"
  if ! curl -fsSL --max-time 60 "$REPO_TARBALL" -o "$work/repo.tgz" \
     || ! tar -xzf "$work/repo.tgz" -C "$new" --strip-components=1; then
    log "Fikk ikke hentet ny versjon fra GitHub, bruker den jeg har."; rm -rf "$work"; return 0
  fi
  for f in "$new"/run.sh "$new"/config.sh "$new"/lib/*.sh "$new"/modules/*.sh; do
    if [ ! -f "$f" ] || ! bash -n "$f"; then
      log "Ny versjon fra GitHub har feil i ${f#$new/}, bruker den jeg har."; rm -rf "$work"; return 0
    fi
  done
  if diff -rq "$new" "$KK_DIR" >/dev/null 2>&1; then rm -rf "$work"; return 0; fi
  chmod 755 "$new/run.sh" "$new/install.sh" 2>/dev/null || true
  mv "$KK_DIR" "$work/old" && mv "$new" "$KK_DIR"
  rm -rf "$work"
  log "Oppdatert fra GitHub, starter ny versjon."
  KK_UPDATED=1 exec bash "$KK_DIR/run.sh" "$@"
}

run_users() {  # run.sh <argumenter> som hver vanlige bruker
  local user uid home shell
  while IFS=: read -r user _ uid _ _ home shell; do
    [ "$uid" -ge 1000 ] && [ "$uid" -lt 60000 ] && [ -d "$home" ] || continue
    case "$shell" in */nologin|*/false) continue ;; esac
    runuser -u "$user" -- bash "$KK_DIR/run.sh" "$@" || log "Brukerdelen feilet for $user."
  done < /etc/passwd
}

start_logging() {
  # Etter selvoppdatering går utskriften allerede til loggen
  [ "${KK_UPDATED:-}" = 1 ] && return 0
  if [ -f "$LOGFILE" ] && [ "$(stat -c %s "$LOGFILE")" -gt 1000000 ]; then
    tail -n 3000 "$LOGFILE" > "$LOGFILE.tmp" && mv "$LOGFILE.tmp" "$LOGFILE"
  fi
  exec > >(tee -a "$LOGFILE") 2>&1
}

need_root() { is_root || { echo "Kjør med sudo."; exit 1; }; }

case "${1:-}" in
  "")
    need_root
    start_logging
    log "=== Start ==="
    if ! wait_for_net; then log "Ingen nett, prøver ved neste kjøring."; exit 0; fi
    self_update
    for m in $MODULES; do run_part root_part "$m"; done
    for m in $(disabled_modules); do run_part uninstall_part "$m"; done
    run_users --bruker
    log "=== Ferdig ==="
    ;;
  --modul)
    m=${2:?Bruk: --modul NAVN}
    if is_root; then
      run_part root_part "$m"
      run_users --bruker-tidlig --modul "$m"
      run_users --bruker --modul "$m"
    else
      run_part user_part "$m"
    fi
    ;;
  --tidlig)
    need_root
    start_logging
    for m in $MODULES; do run_part early_root_part "$m"; done
    run_users --bruker-tidlig
    ;;
  --nullstill)
    need_root
    mkdir -p /var/lib/ubuntu-scripts
    touch /var/lib/ubuntu-scripts/nullstill-neste
    echo "Elevbrukeren nullstilles ved neste oppstart. Start på nytt nå med: sudo reboot"
    ;;
  --bruker-tidlig)
    if [ "${2:-}" = --modul ]; then run_part early_user_part "$3"
    else for m in $MODULES; do run_part early_user_part "$m"; done; fi
    ;;
  --bruker)
    if [ "${2:-}" = --modul ]; then run_part user_part "$3"
    else for m in $MODULES; do run_part user_part "$m"; done; fi
    ;;
  --avinstaller)
    need_root
    for m in $(all_modules); do run_part uninstall_part "$m"; done
    ;;
  --status)
    echo "Mappe:   $KK_DIR"
    echo "På:      $MODULES"
    echo "Av:      $(disabled_modules | tr '\n' ' ')"
    echo "Lokal config: $([ -f /etc/ubuntu-scripts/config.local.sh ] && echo /etc/ubuntu-scripts/config.local.sh || echo ingen)"
    systemctl list-timers ubuntu-scripts.timer --no-pager 2>/dev/null || true
    ;;
  *) echo "Ukjent valg: $1 (se toppen av run.sh)"; exit 1 ;;
esac
