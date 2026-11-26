# desktop: standardoppsett av skrivebordet for hver bruker (Zorin OS / GNOME):
#   - festede apper i taskbar (DESKTOP_FAVORITES), i den rekkefølgen
#   - taskbar-ikonene midtstilt (DESKTOP_TASKBAR_CENTER=1), Zorin taskbar
#   - skjermen slås ikke av og ingen dvale på strøm (DESKTOP_NO_SLEEP_ON_AC=1), låst for alle brukere
#     og innloggingsskjermen, så det ikke kan endres i Innstillinger
# Settes på nytt ved hver kjøring, så elevene alltid starter med samme oppsett.

# dconf-kommando mot brukerens økt hvis den er innlogget, ellers en midlertidig økt
dconf_cmd() {
  local bus="/run/user/$(id -u)/bus"
  if [ -S "$bus" ]; then
    DBUS_SESSION_BUS_ADDRESS="unix:path=$bus" dconf "$@"
  else
    dbus-run-session -- dconf "$@"
  fi
}

# Første .desktop-fil som finnes av "a.desktop|b.desktop|exec:ord".
# "exec:ord" = første snarvei der Exec-linjen inneholder ordet (uansett store/små bokstaver).
resolve_app() {
  local id d f
  local dirs=("$HOME/.local/share/applications" /usr/share/applications /usr/local/share/applications
              /var/lib/flatpak/exports/share/applications /var/lib/snapd/desktop/applications)
  for id in ${1//|/ }; do
    if [[ "$id" == exec:* ]]; then
      for d in "${dirs[@]}"; do
        f=$(grep -il "^Exec=.*${id#exec:}" "$d"/*.desktop 2>/dev/null | head -n1 || true)
        if [ -n "$f" ]; then basename "$f"; return 0; fi
      done
    else
      for d in "${dirs[@]}"; do
        if [ -f "$d/$id" ]; then echo "$id"; return 0; fi
      done
    fi
  done
}

set_favorites() {
  local want=() item id current new
  for item in $DESKTOP_FAVORITES; do
    id=$(resolve_app "$item")
    if [ -n "$id" ]; then want+=("$id"); else log "Fant ikke appen $item, hopper over den."; fi
  done
  [ "${#want[@]}" -gt 0 ] || return 0
  current=$(dconf_cmd read /org/gnome/shell/favorite-apps || true)
  # Alle apper som skal stå: våre først, så det som allerede er festet (med mindre EXACT=1)
  local all=() keep=() a
  mapfile -t all < <(python3 -I - "$DESKTOP_FAVORITES_EXACT" "$current" "${want[@]}" <<'PY'
import ast, sys
exact, current, want = sys.argv[1] == "1", sys.argv[2].strip(), sys.argv[3:]
try:
    cur = list(ast.literal_eval((current[4:] if current.startswith("@as ") else current))) if current else []
except Exception:
    cur = []
for a in (want if exact else want + [a for a in cur if a not in want]):
    print(a)
PY
)
  # Fjern festede apper som ikke finnes lenger (f.eks. snap-versjoner som er avinstallert)
  for a in "${all[@]}"; do
    if [ -n "$(resolve_app "$a")" ]; then keep+=("$a"); else log "Fjerner $a fra taskbar (finnes ikke lenger)."; fi
  done
  new=$(printf "'%s', " "${keep[@]}"); new="[${new%, }]"
  if [ "$new" != "$current" ]; then
    dconf_cmd write /org/gnome/shell/favorite-apps "$new"
    log "Festede apper: $new"
  fi
}

center_taskbar() {
  local key=/org/gnome/shell/extensions/zorin-taskbar/panel-element-positions current new
  if [ ! -d /usr/share/gnome-shell/extensions ] || ! ls -d /usr/share/gnome-shell/extensions/zorin-taskbar* >/dev/null 2>&1; then
    log "Zorin taskbar ikke funnet, hopper over midtstilling."; return 0
  fi
  current=$(dconf_cmd read "$key" || true)
  new=$(python3 -I - "$current" <<'PY'
import ast, json, sys
raw = sys.argv[1].strip()
try:
    data = json.loads(ast.literal_eval(raw)) if raw else {}
except Exception:
    data = {}
# Standardrekkefølgen fra zorin-taskbar (src/panelPositions.js)
defaults = [
    {"element": "leftBox", "visible": True, "position": "stackedTL"},
    {"element": "showAppsButton", "visible": False, "position": "stackedTL"},
    {"element": "taskbar", "visible": True, "position": "stackedTL"},
    {"element": "centerBox", "visible": True, "position": "stackedBR"},
    {"element": "activitiesButton", "visible": True, "position": "stackedBR"},
    {"element": "rightBox", "visible": True, "position": "stackedBR"},
    {"element": "systemMenu", "visible": True, "position": "stackedBR"},
    {"element": "dateMenu", "visible": True, "position": "stackedBR"},
    {"element": "desktopButton", "visible": False, "position": "stackedBR"},
]
if "0" not in data:
    data["0"] = defaults
for elements in data.values():
    for e in elements:
        if e.get("element") == "taskbar":
            e["position"] = "centerMonitor"
print(repr(json.dumps(data, separators=(",", ":"))))
PY
)
  if [ "$new" != "$current" ]; then
    dconf_cmd write "$key" "$new"
    log "Taskbar midtstilt."
  fi
}

user_part() {
  if ! command -v dconf >/dev/null; then log "dconf mangler, hopper over."; return 0; fi
  set_favorites
  if [ "$DESKTOP_TASKBAR_CENTER" = 1 ]; then center_taskbar; fi
}

# --- Strøm: låste systeminnstillinger i dconf (root) ---
POWER_NAME=50-ubuntu-scripts-power
POWER_SETTINGS='[org/gnome/desktop/session]
idle-delay=uint32 0

[org/gnome/settings-daemon/plugins/power]
sleep-inactive-ac-type='"'nothing'"
POWER_LOCKS='/org/gnome/desktop/session/idle-delay
/org/gnome/settings-daemon/plugins/power/sleep-inactive-ac-type'

# write_if_changed <fil> <innhold>: returnerer 0 hvis filen ble endret
write_if_changed() {
  if [ "$(cat "$1" 2>/dev/null)" = "$2" ]; then return 1; fi
  mkdir -p "$(dirname "$1")"
  printf '%s\n' "$2" > "$1"
}

# ensure_profile <profilfil> <linje>...: profilen må lese system-databasen, ellers virker ikke låsene
ensure_profile() {
  local f=$1 line changed=1; shift
  [ -f "$f" ] || { printf 'user-db:user\n' > "$f"; changed=0; }
  for line in "$@"; do
    grep -qxF "$line" "$f" || { echo "$line" >> "$f"; changed=0; }
  done
  return $changed
}

power_lock() {
  local changed=1
  ensure_profile /etc/dconf/profile/user "system-db:local" && changed=0
  write_if_changed "/etc/dconf/db/local.d/$POWER_NAME" "$POWER_SETTINGS" && changed=0
  write_if_changed "/etc/dconf/db/local.d/locks/$POWER_NAME" "$POWER_LOCKS" && changed=0
  # Innloggingsskjermen (gdm3) går ellers i dvale etter 20 minutter, også på strøm
  if [ -f /etc/dconf/profile/gdm ]; then
    ensure_profile /etc/dconf/profile/gdm "system-db:gdm" && changed=0
    write_if_changed "/etc/dconf/db/gdm.d/$POWER_NAME" "$POWER_SETTINGS" && changed=0
  fi
  if [ "$changed" = 0 ]; then
    dconf update
    log "Skjermen slås ikke av og ingen dvale på strøm (låst for alle brukere og innloggingsskjermen)."
  fi
}

power_unlock() {
  local f found=1
  for f in /etc/dconf/db/local.d/$POWER_NAME /etc/dconf/db/local.d/locks/$POWER_NAME /etc/dconf/db/gdm.d/$POWER_NAME; do
    [ -f "$f" ] && { rm -f "$f"; found=0; }
  done
  if [ "$found" = 0 ]; then dconf update; log "Fjernet låste strøminnstillinger."; fi
}

root_part() {
  command -v dconf >/dev/null || return 0
  if [ "${DESKTOP_NO_SLEEP_ON_AC:-0}" = 1 ]; then power_lock; else power_unlock; fi
}

uninstall_part() {
  command -v dconf >/dev/null || return 0
  power_unlock
}
