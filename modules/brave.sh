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

  # Policy: oppstartsside, kurs-bokmerker, ingen passordlagring, uten Rewards/Wallet/VPN/AI, og trygt søk
  mkdir -p "$(dirname "$POLICY")"
  write_if_changed "$POLICY" "$(python3 -I - "$BRAVE_URL" "$BRAVE_BOOKMARKS" "$BRAVE_SAFE_SEARCH" <<'PY'
import json, sys
url, bookmarks, safe = sys.argv[1], sys.argv[2], sys.argv[3] == "1"
marks = []
for line in bookmarks.splitlines():
    if "|" in line:
        name, link = line.split("|", 1)
        marks.append({"name": name.strip(), "url": link.strip()})
policy = {
    "RestoreOnStartup": 4,
    "RestoreOnStartupURLs": [url],
    "HomepageLocation": url,
    "ShowHomeButton": True,
    "BookmarkBarEnabled": True,
    "ManagedBookmarks": [{"toplevel_name": "Kurs"}] + marks,
    "PasswordManagerEnabled": False,
    "AutofillCreditCardEnabled": False,
    "BrowserSignin": 0,
    "SyncDisabled": True,
    "DefaultBrowserSettingEnabled": False,
    "BraveRewardsDisabled": True,
    "BraveWalletDisabled": True,
    "BraveVPNDisabled": True,
    "BraveAIChatEnabled": False,
    "BraveNewsDisabled": True,
    "BraveTalkDisabled": True,
    # Ingen "nytt i denne versjonen"/velkomstfaner foran oppgavesiden etter oppdateringer
    "PromotionsEnabled": False,
    "PromotionalTabsEnabled": False,
}
if safe:
    policy["ForceGoogleSafeSearch"] = True
    policy["ForceYouTubeRestrict"] = 1
print(json.dumps(policy, indent=2, ensure_ascii=False))
PY
)" && log "Brave-policy oppdatert."

  # Åpne siden ved innlogging, for alle brukere
  cat > "$LAUNCHER" <<EOF
#!/bin/sh
sleep 3
# Ble maskinen slått av uten at Brave lukket seg, spør Brave om å gjenopprette sider.
# Merk profilen som riktig lukket (bare når Brave ikke kjører), så den åpner rett side.
if ! pgrep -u "\$(id -u)" -x brave >/dev/null 2>&1; then
  for prefs in "\$HOME/.config/BraveSoftware/Brave-Browser/Default/Preferences" \\
               "\$HOME/.var/app/com.brave.Browser/config/BraveSoftware/Brave-Browser/Default/Preferences"; do
    [ -f "\$prefs" ] && sed -i 's/"exited_cleanly":false/"exited_cleanly":true/g; s/"exit_type":"[A-Za-z]*"/"exit_type":"Normal"/g' "\$prefs"
  done
fi
FLAGS="--hide-crash-restore-bubble --no-first-run"
# apt-versjonen åpner siden selv via policyen; flatpak leser ikke /etc/brave, så den får adressen
if command -v brave-browser >/dev/null; then exec brave-browser \$FLAGS
elif command -v brave >/dev/null; then exec brave \$FLAGS
else exec flatpak run com.brave.Browser \$FLAGS "$BRAVE_URL"
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

# Brave som standard nettleser for hver bruker
user_part() {
  local id
  for id in brave-browser.desktop com.brave.Browser.desktop; do
    if [ -f "/usr/share/applications/$id" ] || [ -f "/var/lib/flatpak/exports/share/applications/$id" ]; then
      if [ "$(xdg-settings get default-web-browser 2>/dev/null)" != "$id" ]; then
        xdg-settings set default-web-browser "$id" 2>/dev/null && log "Brave er standard nettleser."
      fi
      return 0
    fi
  done
}

# Kjøres når modulen er slått av: Brave blir stående, men åpner ikke lenger siden
uninstall_part() {
  if [ -f "$AUTOSTART" ] || [ -f "$POLICY" ]; then
    rm -f "$AUTOSTART" "$LAUNCHER" "$POLICY"
    log "Fjernet autostart og oppstartsside."
  fi
}
