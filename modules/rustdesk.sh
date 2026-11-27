# rustdesk: fjernstyring med RustDesk (versjon RUSTDESK_VERSION), med direkte IP-tilgang på port 21118.
# Bare fast passord, og bare fra maskinene i RUSTDESK_WHITELIST (admin-PC-en på LAN og Tailscale).
# Passordet (RUSTDESK_PASSWORD) kommer fra /etc/ubuntu-scripts/config.local.sh, aldri fra repoet.
# Skjermen deles bare under Xorg, så Wayland slås av i GDM (gjelder fra neste oppstart).
# Slått av: brannmurreglene modulen la til fjernes. RustDesk, innstillingene og Xorg blir stående,
# som for de andre modulene (programmet fjernes ikke).

GDM_CONF=/etc/gdm3/custom.conf
RUSTDESK_TOML=/root/.config/rustdesk/RustDesk2.toml
RUSTDESK_PW_HASH=/etc/ubuntu-scripts/.rustdesk-pw.sha256
UFW_COMMENT="ubuntu-scripts rustdesk"

# WaylandEnable=false under [daemon], resten av fila (f.eks. AutomaticLogin) røres ikke
disable_wayland() {
  python3 -I - "$GDM_CONF" <<'PY'
import sys
path = sys.argv[1]
lines = open(path).read().splitlines()
section, start, end, ok = None, None, None, False
for i, line in enumerate(lines):
    s = line.strip()
    if s.startswith("["):
        if section == "daemon": end = i
        section = s.strip("[]")
        if section == "daemon": start = i
    elif section == "daemon" and s.replace(" ", "") == "WaylandEnable=false":
        ok = True
if ok:
    sys.exit()
if start is None:
    lines += ["", "[daemon]"]; start = len(lines) - 1; end = len(lines)
if end is None: end = len(lines)
block = [l for l in lines[start + 1:end] if l.strip().split("=", 1)[0].strip() != "WaylandEnable"]
lines = lines[:start + 1] + ["WaylandEnable=false"] + block + lines[end:]
open(path, "w").write("\n".join(lines) + "\n")
print("endret")
PY
}

# toml_option <nøkkel>: verdien under [options] i RustDesk2.toml (det finnes ingen --get-option)
toml_option() {
  python3 -I - "$RUSTDESK_TOML" "$1" <<'PY'
import sys
path, key = sys.argv[1], sys.argv[2]
section = None
try:
    lines = open(path).read().splitlines()
except FileNotFoundError:
    sys.exit()
for line in lines:
    s = line.strip()
    if s.startswith("["):
        section = s.strip("[]")
    elif section == "options" and "=" in s:
        k, v = s.split("=", 1)
        if k.strip() == key:
            print(v.strip().strip("'\"")); break
PY
}

# ufw_rules: reglene for port 21118, én per linje, slik "ufw show added" skriver dem (uten "ufw ")
ufw_rules() {
  local cidr
  echo "allow in on tailscale0 to any port 21118 proto tcp"
  for cidr in $RUSTDESK_LAN_CIDRS; do echo "allow from $cidr to any port 21118 proto tcp"; done
}

ufw_active() { command -v ufw >/dev/null && ufw status 2>/dev/null | grep -q '^Status: active'; }

root_part() {
  local arch deb key want changed=1 added rule

  if [ -f "$GDM_CONF" ]; then
    [ -n "$(disable_wayland)" ] && log "Wayland slått av i GDM, RustDesk bruker Xorg fra neste oppstart."
  else
    log "Fant ikke $GDM_CONF, kan ikke slå av Wayland."
  fi

  if [ "$(pkg_version rustdesk)" != "$RUSTDESK_VERSION" ]; then
    arch=$(uname -m)
    deb="$KK_TMP/rustdesk.deb"
    curl -fsSL "https://github.com/rustdesk/rustdesk/releases/download/$RUSTDESK_VERSION/rustdesk-$RUSTDESK_VERSION-$arch.deb" -o "$deb"
    apt_install "$deb"
    log "RustDesk: $(pkg_version rustdesk)"
  fi
  systemctl enable --now rustdesk >/dev/null 2>&1 || true

  # Innstillingene settes bare når de avviker, så tjenesten bare startes på nytt ved endring
  while IFS='=' read -r key want; do
    if [ "$(toml_option "$key")" != "$want" ]; then
      rustdesk --option "$key" "$want" >/dev/null 2>&1 || true
      log "RustDesk: $key = $want"; changed=0
    fi
  done <<EOF
direct-server=Y
approve-mode=password
verification-method=use-permanent-password
whitelist=$RUSTDESK_WHITELIST
EOF

  # Fast passord: settes bare når det er endret (sammenlignes med en sha256, aldri i loggen)
  if [ -z "${RUSTDESK_PASSWORD:-}" ]; then
    log "RUSTDESK_PASSWORD er ikke satt på denne laptopen (kjør install.sh med RUSTDESK_PASSWORD=...)."
  elif [ "${#RUSTDESK_PASSWORD}" -lt 8 ]; then
    log "RUSTDESK_PASSWORD er for kort (minst 8 tegn), passordet er ikke endret."
  else
    want=$(printf '%s' "$RUSTDESK_PASSWORD" | sha256sum | cut -d' ' -f1)
    if [ "$(cat "$RUSTDESK_PW_HASH" 2>/dev/null)" != "$want" ]; then
      rustdesk --password "$RUSTDESK_PASSWORD" >/dev/null 2>&1
      (umask 077; echo "$want" > "$RUSTDESK_PW_HASH")
      log "RustDesk-passordet er satt."; changed=0
    fi
  fi
  [ "$changed" = 0 ] && systemctl restart rustdesk

  # Brannmuren: åpne 21118 fra Tailscale og LAN, bare hvis ufw er på (den slås ikke på her)
  if ufw_active; then
    added=$(ufw show added 2>/dev/null)
    while IFS= read -r rule; do
      # Finnes regelen fra før (med eller uten kommentar), legges den ikke til igjen
      grep -qE "^ufw $rule( comment .*)?$" <<< "$added" && continue
      # shellcheck disable=SC2086
      ufw $rule comment "$UFW_COMMENT" >/dev/null && log "Brannmur: $rule"
    done < <(ufw_rules)
  fi
  return 0
}

# Slått av: fjern brannmurreglene modulen la til (de med vår kommentar). RustDesk blir stående.
uninstall_part() {
  command -v ufw >/dev/null || return 0
  local rule
  ufw show added 2>/dev/null | grep -F "comment '$UFW_COMMENT'" | sed -e 's/^ufw //' -e 's/ comment .*//' |
  while IFS= read -r rule; do
    # shellcheck disable=SC2086
    ufw delete $rule >/dev/null && log "Fjernet brannmurregelen: $rule"
  done
  return 0
}
