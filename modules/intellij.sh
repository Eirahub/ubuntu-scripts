# intellij: IntelliJ IDEA Community, låst til INTELLIJ_MAJOR (2025.2 er siste egne Community-utgave).
# Henter siste INTELLIJ_MAJOR.x fra JetBrains, sjekker SHA-256, installerer i /opt/intellij-idea-community
# og lager snarveien intellij-idea-community.desktop. Fjerner snap-versjonen så elevene bare ser én.

IDEA_DIR=/opt/intellij-idea-community
IDEA_DESKTOP=/usr/share/applications/intellij-idea-community.desktop

root_part() {
  local info version link sums installed work want
  info=$(curl -fsSL -A "$UA" "https://data.services.jetbrains.com/products/releases?code=IIC&majorVersion=$INTELLIJ_MAJOR&latest=true&type=release" \
    | python3 -I -c '
import json, sys
r = json.load(sys.stdin)["IIC"][0]
d = r["downloads"]["linux"]
print(r["version"], d["link"], d["checksumLink"])') || { log "Fikk ikke kontakt med JetBrains."; return 0; }
  read -r version link sums <<< "$info"
  installed=$(cat "$IDEA_DIR/.ubuntu-scripts-version" 2>/dev/null || true)

  if [ "$installed" = "$version" ]; then
    log "IntelliJ $version er på plass."
  elif pgrep -f "$IDEA_DIR/" >/dev/null 2>&1; then
    log "IntelliJ kjører, oppdaterer til $version neste gang."
  else
    log "Installerer IntelliJ IDEA Community $version (ca. 1 GB)."
    # Last ned på disk, ikke i /tmp (kan være i minnet)
    work=$(mktemp -d /opt/.intellij-download.XXXXXX)
    curl -fsSL -A "$UA" "$link" -o "$work/idea.tar.gz"
    want=$(curl -fsSL -A "$UA" "$sums" | cut -d' ' -f1)
    if [ "$(sha256sum "$work/idea.tar.gz" | cut -d' ' -f1)" != "$want" ]; then
      log "Sjekksum feilet for IntelliJ, hopper over."; rm -rf "$work"; return 0
    fi
    mkdir -p "$work/new"
    tar -xzf "$work/idea.tar.gz" -C "$work/new" --strip-components=1
    echo "$version" > "$work/new/.ubuntu-scripts-version"
    rm -rf "$IDEA_DIR"
    mv "$work/new" "$IDEA_DIR"
    rm -rf "$work"
    ln -sf "$IDEA_DIR/bin/idea" /usr/local/bin/idea
    log "IntelliJ $version installert."
  fi

  cat > "$IDEA_DESKTOP" <<EOF
[Desktop Entry]
Type=Application
Name=IntelliJ IDEA Community $INTELLIJ_MAJOR
Comment=Java-utvikling
Exec=$IDEA_DIR/bin/idea %f
Icon=$IDEA_DIR/bin/idea.svg
Categories=Development;IDE;
StartupWMClass=jetbrains-idea-ce
Terminal=false
EOF

  if command -v snap >/dev/null && snap list intellij-idea-community >/dev/null 2>&1; then
    snap remove intellij-idea-community >/dev/null && log "Fjernet snap-versjonen."
  fi
}
