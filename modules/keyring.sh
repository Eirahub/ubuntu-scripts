# keyring: hindrer "Lås opp nøkkelring"-vinduer (Brave, VS Code osv.).
# Gir hver bruker en standard-nøkkelring uten passord. Den lagres ukryptert, som er greit fordi
# maskinene aldri skal ha noe hemmelig på seg. Gamle nøkkelringer flyttes til keyrings/gammel-<dato>/.
# Kjøres før innloggingsskjermen (early_user_part), fordi gnome-keyring holder filene åpne under en økt.

KEYRING_NAME="Default_keyring"

early_user_part() {
  local dir="$HOME/.local/share/keyrings" f others backup
  # Allerede i orden: standard er vår ring uten passord, og ingen andre ringer finnes
  others=$(find "$dir" -maxdepth 1 -name '*.keyring' ! -name "$KEYRING_NAME.keyring" 2>/dev/null || true)
  if [ -f "$dir/$KEYRING_NAME.keyring" ] && [ "$(cat "$dir/default" 2>/dev/null)" = "$KEYRING_NAME" ] && [ -z "$others" ]; then
    return 0
  fi
  if [ -S "/run/user/$(id -u)/bus" ]; then
    log "Brukeren er innlogget, ordner nøkkelringen ved neste oppstart."; return 0
  fi

  mkdir -p "$dir"; chmod 700 "$dir"
  if [ -n "$others" ]; then
    backup="$dir/gammel-$(date +%F-%H%M%S)"
    mkdir -p "$backup"
    while IFS= read -r f; do mv "$f" "$backup/"; done <<< "$others"
    log "Flyttet gamle nøkkelringer til $backup."
  fi
  # Ukryptert nøkkelring (gnome-keyring sitt tekstformat for ringer uten passord)
  cat > "$dir/$KEYRING_NAME.keyring" <<'EOF'
[keyring]
display-name=Default keyring
ctime=0
mtime=0
lock-on-idle=false
lock-after=false
EOF
  chmod 600 "$dir/$KEYRING_NAME.keyring"
  echo "$KEYRING_NAME" > "$dir/default"
  log "Nøkkelring uten passord er satt opp."
}
