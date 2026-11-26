# brave: installer/oppdater Brave, og åpne BRAVE_URL ved innlogging og som oppstartsside.

AUTOSTART=/etc/xdg/autostart/kodeklubb-brave.desktop
LAUNCHER=/usr/local/bin/kodeklubb-brave
POLICY=/etc/brave/policies/managed/kodeklubb.json

root_part() {
  # Installer fra Braves apt-repo hvis Brave ikke finnes (flatpak telles også)
  if [ -f /etc/apt/sources.list.d/brave.list ] || { ! command -v brave-browser >/dev/null \
       && ! command -v brave >/dev/null && ! flatpak info com.brave.Browser >/dev/null 2>&1; }; then
    add_apt_repo brave https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg \
      "https://brave-browser-apt-release.s3.brave.com/ stable main"
    apt_install brave-browser
    log "Brave: $(pkg_version brave-browser)"
  fi

  # Oppstartsside når Brave åpnes for hånd
  mkdir -p "$(dirname "$POLICY")"
  cat > "$POLICY" <<EOF
{
  "RestoreOnStartup": 4,
  "RestoreOnStartupURLs": ["$BRAVE_URL"],
  "HomepageLocation": "$BRAVE_URL",
  "ShowHomeButton": true
}
EOF

  # Åpne siden ved innlogging, for alle brukere
  cat > "$LAUNCHER" <<EOF
#!/bin/sh
sleep 3
# apt-versjonen åpner siden selv via policyen; flatpak leser ikke /etc/brave, så den får adressen
if command -v brave-browser >/dev/null; then exec brave-browser
elif command -v brave >/dev/null; then exec brave
else exec flatpak run com.brave.Browser "$BRAVE_URL"
fi
EOF
  chmod 755 "$LAUNCHER"
  cat > "$AUTOSTART" <<EOF
[Desktop Entry]
Type=Application
Name=Kodeklubb oppgaver
Exec=$LAUNCHER
X-GNOME-Autostart-enabled=true
NoDisplay=true
EOF
}

# Kjøres når modulen er slått av: Brave blir stående, men åpner ikke lenger siden
uninstall_part() {
  if [ -f "$AUTOSTART" ] || [ -f "$POLICY" ]; then
    rm -f "$AUTOSTART" "$LAUNCHER" "$POLICY"
    log "Fjernet autostart og oppstartsside."
  fi
}
