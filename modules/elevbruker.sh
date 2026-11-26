# elevbruker: elevbrukeren ELEV_USER finnes, er aldri admin, og logges inn automatisk (ELEV_AUTOLOGIN=1).
# Passordet (ELEV_PASSWORD) trengs nesten aldri, men settes så brukeren kan låses opp om det skulle trengs.
# Admin-kontoen(e) på laptopen røres ikke.

GDM_CONF=/etc/gdm3/custom.conf

# set_autologin <bruker|tom>: tom slår av automatisk innlogging (bare hvis den gjelder elevbrukeren)
set_autologin() {
  [ -f "$GDM_CONF" ] || { log "Fant ikke $GDM_CONF, kan ikke sette automatisk innlogging."; return 0; }
  python3 -I - "$GDM_CONF" "$1" "$ELEV_USER" <<'PY'
import sys
path, user, elev = sys.argv[1], sys.argv[2], sys.argv[3]
lines = open(path).read().splitlines()
want = {"AutomaticLoginEnable": "true", "AutomaticLogin": user} if user else {"AutomaticLoginEnable": "false"}
current = {}
section, start, end = None, None, None
for i, line in enumerate(lines):
    s = line.strip()
    if s.startswith("["):
        if section == "daemon": end = i
        section = s.strip("[]")
        if section == "daemon": start = i
    elif section == "daemon" and "=" in s and not s.startswith("#"):
        k, v = s.split("=", 1); current[k.strip()] = v.strip()
if start is None:
    lines += ["", "[daemon]"]; start = len(lines) - 1; end = len(lines)
if end is None: end = len(lines)
if not user and current.get("AutomaticLogin") != elev:
    sys.exit()      # autologin gjelder en annen bruker: ikke rør
if all(current.get(k) == v for k, v in want.items()):
    sys.exit()
block = [l for l in lines[start + 1:end] if l.strip().split("=", 1)[0].strip() not in want]
block = [f"{k}={v}" for k, v in want.items()] + block
lines = lines[:start + 1] + block + lines[end:]
open(path, "w").write("\n".join(lines) + "\n")
print("endret")
PY
}

root_part() {
  local u=$ELEV_USER home g
  if ! id "$u" >/dev/null 2>&1; then
    useradd -m -s /bin/bash -c "Elev" "$u"
    log "Laget elevbrukeren $u."
  fi
  echo "$u:$ELEV_PASSWORD" | chpasswd
  # Aldri admin
  for g in sudo adm; do
    if id -nG "$u" | tr ' ' '\n' | grep -qx "$g"; then gpasswd -d "$u" "$g" >/dev/null; log "Fjernet $u fra gruppen $g."; fi
  done
  # Hopp over GNOME sitt velkomstoppsett
  home=$(home_of "$u")
  if [ ! -f "$home/.config/gnome-initial-setup-done" ]; then
    install -d -o "$u" -g "$u" "$home/.config"
    echo yes > "$home/.config/gnome-initial-setup-done"; chown "$u:$u" "$home/.config/gnome-initial-setup-done"
  fi
  if [ "${ELEV_AUTOLOGIN:-0}" = 1 ]; then
    [ -n "$(set_autologin "$u")" ] && log "$u logges inn automatisk (fra neste oppstart)."
  else
    [ -n "$(set_autologin "")" ] && log "Automatisk innlogging slått av."
  fi
  return 0
}

# Slått av: slå av automatisk innlogging, men la brukeren og filene være
uninstall_part() {
  [ -n "$(set_autologin "")" ] && log "Automatisk innlogging slått av."
  return 0
}
