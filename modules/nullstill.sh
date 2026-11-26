# nullstill: tilbakestiller elevbrukeren (ELEV_USER) til en ren hjemmemappe, før innloggingsskjermen.
# Skjer når RESET_GENERATION i config.sh økes (ved oppstarten etter at laptopen har hentet endringen),
# eller ved neste oppstart etter "sudo /opt/ubuntu-scripts/run.sh --nullstill" på laptopen.
# Beholdes: RESET_KEEP (MultiMC med instanser og Microsoft-innlogging). Verdener og Halison-prosjekter
# i instansene slettes, med mindre RESET_KEEP_WORLDS=1.

STATE_DIR=/var/lib/ubuntu-scripts
STATE="$STATE_DIR/nullstill-generasjon"
REQUEST="$STATE_DIR/nullstill-neste"

reset_user() {
  local u=$ELEV_USER home tmp p
  id "$u" >/dev/null 2>&1 || { log "Fant ikke $u, ingenting å nullstille."; return 0; }
  home=$(home_of "$u")
  case "$home" in /home/?*) ;; *) log "Uventet hjemmemappe '$home' for $u, nullstiller ikke."; return 1 ;; esac
  if loginctl list-users --no-legend 2>/dev/null | awk '{print $2}' | grep -qx "$u"; then
    log "$u er innlogget, nullstiller ved neste oppstart."; return 1
  fi

  tmp=$(mktemp -d /home/.ubuntu-scripts-nullstill.XXXXXX)
  for p in $RESET_KEEP; do
    if [ -e "$home/$p" ]; then mkdir -p "$tmp/$(dirname "$p")"; mv "$home/$p" "$tmp/$p"; fi
  done
  rm -rf "$home"
  cp -a /etc/skel "$home"
  for p in $RESET_KEEP; do
    if [ -e "$tmp/$p" ]; then mkdir -p "$home/$(dirname "$p")"; mv "$tmp/$p" "$home/$p"; fi
  done
  rm -rf "$tmp"
  if [ "${RESET_KEEP_WORLDS:-0}" != 1 ]; then
    find "$home" -maxdepth 8 -type d \( -path '*/instances/*/.minecraft/saves' -o -path '*/instances/*/.minecraft/halisoncode/projects' \) \
      -exec sh -c 'rm -rf "$1"/* "$1"/.[!.]* 2>/dev/null' _ {} \;
  fi
  mkdir -p "$home/.config"; echo yes > "$home/.config/gnome-initial-setup-done"
  chown -R "$u:$u" "$home"; chmod 750 "$home"
  find /tmp /var/tmp -maxdepth 1 -user "$u" -exec rm -rf {} + 2>/dev/null || true
  log "Nullstilte $u (beholdt: $RESET_KEEP)."
}

early_root_part() {
  mkdir -p "$STATE_DIR"
  # Første gang: husk generasjonen uten å nullstille
  if [ ! -f "$STATE" ]; then echo "${RESET_GENERATION:-0}" > "$STATE"; fi
  local done; done=$(cat "$STATE")
  if [ -f "$REQUEST" ] || [ "${RESET_GENERATION:-0}" -gt "${done:-0}" ]; then
    if reset_user; then
      echo "${RESET_GENERATION:-0}" > "$STATE"
      rm -f "$REQUEST"
    fi
  fi
}
