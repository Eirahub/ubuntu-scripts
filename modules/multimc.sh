# multimc: installer MultiMC i ~/MULTIMC_NEW_DIR hvis den mangler, og oppdater den når MULTIMC_URL endres.
# Setter også minnet Minecraft får (MULTIMC_MEMORY_MB, eller ut fra RAM hvis tom).

root_part() {
  # Qt5-bibliotekene MultiMC trenger
  apt_install libqt5core5a libqt5gui5 libqt5network5 libqt5widgets5
}

user_part() {
  update_multimc
  set_memory
}

set_memory() {
  local mb d total
  if pgrep -u "$(id -u)" -x MultiMC >/dev/null 2>&1; then return 0; fi   # MultiMC skriver filen når den lukkes
  mb=${MULTIMC_MEMORY_MB:-}
  if [ -z "$mb" ]; then
    # En tredel av RAM, mellom 2 og 4 GB, rundet ned til 512 MB
    total=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)
    mb=$(( total / 3 / 512 * 512 )); [ "$mb" -lt 2048 ] && mb=2048; [ "$mb" -gt 4096 ] && mb=4096
  fi
  while IFS= read -r d; do
    [ -n "$(ini_set "$d/multimc.cfg" "MaxMemAlloc=$mb" "MinMemAlloc=512")" ] && log "MultiMC: Minecraft får $mb MB minne."
  done < <(multimc_dirs)
  return 0
}

update_multimc() {
  local dirs etag old d etag_file="$HOME/.local/state/kodeklubb/multimc.etag"
  mkdir -p "$(dirname "$etag_file")"
  dirs=$(multimc_dirs)
  if [ -z "$dirs" ]; then
    dirs="$HOME/$MULTIMC_NEW_DIR"
    log "MultiMC ikke funnet, installerer i $dirs."
    mkdir -p "$dirs"
    rm -f "$etag_file"
  fi
  etag=$(curl -fsSIL -A "$UA" "$MULTIMC_URL" | tr -d '\r' | awk -F': ' 'tolower($1)=="etag"{print $2}' | tail -n1)
  old=$(cat "$etag_file" 2>/dev/null || true)
  if [ -n "$etag" ] && [ "$etag" = "$old" ]; then
    log "MultiMC er oppdatert."
    return 0
  fi
  if pgrep -u "$(id -u)" -x MultiMC >/dev/null 2>&1; then
    log "MultiMC kjører, oppdaterer neste gang."
    return 0
  fi
  curl -fsSL -A "$UA" "$MULTIMC_URL" -o "$KK_TMP/mmc.tar.gz"
  while IFS= read -r d; do
    # Pakkes ut over den gamle; instances, innstillinger og kontoer blir liggende
    tar -xzf "$KK_TMP/mmc.tar.gz" -C "$d" --strip-components=1
    log "MultiMC oppdatert i $d."
  done <<< "$dirs"
  echo "$etag" > "$etag_file"
  desktop_entry "$(head -n1 <<< "$dirs")"
}

desktop_entry() {  # lager en snarvei bare hvis det ikke finnes en MultiMC-snarvei fra før
  local f="$HOME/.local/share/applications/multimc.desktop"
  if grep -qil '^Exec=.*multimc' "$HOME/.local/share/applications/"*.desktop /usr/share/applications/*.desktop 2>/dev/null; then
    return 0
  fi
  mkdir -p "$(dirname "$f")"
  cat > "$f" <<EOF
[Desktop Entry]
Type=Application
Name=MultiMC
Comment=Minecraft-launcher
Exec=$1/MultiMC
Icon=applications-games
Categories=Game;
Terminal=false
EOF
}
