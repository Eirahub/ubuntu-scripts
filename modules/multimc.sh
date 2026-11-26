# multimc: installer MultiMC i ~/MULTIMC_NEW_DIR hvis den mangler, og oppdater den når MULTIMC_URL endres.

root_part() {
  # Qt5-bibliotekene MultiMC trenger
  apt_install libqt5core5a libqt5gui5 libqt5network5 libqt5widgets5
}

user_part() {
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

desktop_entry() {
  local f="$HOME/.local/share/applications/multimc.desktop"
  [ -f "$f" ] && return 0
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
