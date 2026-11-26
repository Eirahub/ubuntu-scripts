# systeminnstillinger: felles oppsett for hele maskinen.
#   - GNOME-innstillinger for alle brukere fra files/gnome.ini, låst etter files/gnome-laast.txt
#   - innloggingsskjermen går ikke i dvale på strøm
#   - tidssone og tastatur (SYS_TIMEZONE, SYS_KEYBOARD), også på innloggingsskjermen
#   - sikkerhetsoppdateringer installeres i bakgrunnen, uten varsler
#   - bakgrunnsbilde med laptopens navn og WALLPAPER_TEXT

DB_NAME=50-ubuntu-scripts
WALLPAPER=/usr/share/backgrounds/ubuntu-scripts.svg
OLD_POWER=50-ubuntu-scripts-power   # fra en tidligere versjon

# ensure_profile <profilfil> <linje>...: profilen må lese system-databasen, ellers virker ikke låsene
ensure_profile() {
  local f=$1 line changed=1; shift
  [ -f "$f" ] || { printf 'user-db:user\n' > "$f"; changed=0; }
  for line in "$@"; do
    grep -qxF "$line" "$f" || { echo "$line" >> "$f"; changed=0; }
  done
  return $changed
}

make_wallpaper() {
  local name text svg
  name=$(hostname | tr -cd 'A-Za-z0-9._-')
  text=$(printf '%s' "$WALLPAPER_TEXT" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')
  svg="<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"1920\" height=\"1080\" viewBox=\"0 0 1920 1080\">
  <rect width=\"1920\" height=\"1080\" fill=\"#14213d\"/>
  <text x=\"960\" y=\"500\" font-family=\"Inter, Ubuntu, sans-serif\" font-size=\"150\" font-weight=\"700\" fill=\"#ffffff\" text-anchor=\"middle\">$name</text>
  <text x=\"960\" y=\"610\" font-family=\"Inter, Ubuntu, sans-serif\" font-size=\"56\" fill=\"#a9bce0\" text-anchor=\"middle\">$text</text>
</svg>"
  write_if_changed "$WALLPAPER" "$svg" && log "Bakgrunnsbilde laget for $name."
  return 0
}

gnome_settings() {
  local changed=1 f
  ensure_profile /etc/dconf/profile/user "system-db:local" && changed=0
  write_if_changed "/etc/dconf/db/local.d/$DB_NAME" "$(cat "$KK_DIR/files/gnome.ini")" && changed=0
  write_if_changed "/etc/dconf/db/local.d/locks/$DB_NAME" "$(cat "$KK_DIR/files/gnome-laast.txt")" && changed=0
  # Innloggingsskjermen (gdm3) går ellers i dvale etter 20 minutter, også på strøm
  if [ -f /etc/dconf/profile/gdm ]; then
    ensure_profile /etc/dconf/profile/gdm "system-db:gdm" && changed=0
    write_if_changed "/etc/dconf/db/gdm.d/$DB_NAME" "[org/gnome/settings-daemon/plugins/power]
sleep-inactive-ac-type='nothing'" && changed=0
  fi
  for f in /etc/dconf/db/local.d/$OLD_POWER /etc/dconf/db/local.d/locks/$OLD_POWER /etc/dconf/db/gdm.d/$OLD_POWER; do
    [ -f "$f" ] && { rm -f "$f"; changed=0; }
  done
  if [ "$changed" = 0 ]; then
    dconf update
    log "GNOME-innstillinger oppdatert for alle brukere."
  fi
}

root_part() {
  make_wallpaper
  if command -v dconf >/dev/null; then gnome_settings; fi

  if [ -n "${SYS_TIMEZONE:-}" ] && [ "$(timedatectl show -p Timezone --value 2>/dev/null)" != "$SYS_TIMEZONE" ]; then
    timedatectl set-timezone "$SYS_TIMEZONE" && log "Tidssone satt til $SYS_TIMEZONE."
  fi
  if [ -n "${SYS_KEYBOARD:-}" ] && ! localectl status 2>/dev/null | grep -q "X11 Layout: $SYS_KEYBOARD\$"; then
    localectl set-x11-keymap "$SYS_KEYBOARD" && log "Tastatur satt til $SYS_KEYBOARD."
  fi

  # Sikkerhetsoppdateringer i bakgrunnen
  apt_install unattended-upgrades
  write_if_changed /etc/apt/apt.conf.d/20auto-upgrades 'APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";' && log "Automatiske sikkerhetsoppdateringer slått på."
  return 0
}

# De låste verdiene leses av økta først ved neste innlogging. Sett dem også i en innlogget økt,
# så de virker med en gang.
user_part() {
  command -v dconf >/dev/null || return 0
  [ -S "/run/user/$(id -u)/bus" ] || return 0
  local key value
  while IFS=$'\t' read -r key value; do
    dconf_set "$key" "$value"
  done < <(python3 -I - "$KK_DIR/files/gnome.ini" "$KK_DIR/files/gnome-laast.txt" <<'PY'
import configparser, sys
ini = configparser.ConfigParser(interpolation=None, comment_prefixes=("#",), strict=False)
ini.optionxform = str
ini.read(sys.argv[1])
locked = {l.strip() for l in open(sys.argv[2]) if l.strip()}
for section in ini.sections():
    for key, value in ini.items(section):
        path = f"/{section}/{key}"
        if path in locked:
            print(f"{path}\t{value}")
PY
)
}

uninstall_part() {
  local f found=1
  for f in /etc/dconf/db/local.d/$DB_NAME /etc/dconf/db/local.d/locks/$DB_NAME /etc/dconf/db/gdm.d/$DB_NAME; do
    [ -f "$f" ] && { rm -f "$f"; found=0; }
  done
  if [ "$found" = 0 ] && command -v dconf >/dev/null; then dconf update; log "Fjernet GNOME-innstillingene."; fi
}
