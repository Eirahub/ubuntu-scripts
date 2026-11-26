# Felles hjelpefunksjoner for run.sh og modulene.

UA="ubuntu-scripts"

log() { echo "$(date '+%F %T') [$(id -un)]${MODULE:+ $MODULE:} $*"; }

is_root() { [ "$(id -u)" = 0 ]; }

wait_for_net() {  # opptil 3 minutter, wifi kan bruke litt tid etter oppstart
  local i
  for i in $(seq 1 36); do
    curl -fsS -o /dev/null --max-time 5 https://api.github.com && return 0
    sleep 5
  done
  return 1
}

# --- apt (root) ---

# add_apt_repo <navn> <nøkkel-url> <deb-linje uten [signed-by]>
add_apt_repo() {
  local name=$1 key_url=$2 line=$3
  local keyring="/etc/apt/keyrings/$name.gpg" list="/etc/apt/sources.list.d/$name.list"
  local want="deb [signed-by=$keyring] $line"
  if [ -s "$keyring" ] && [ "$(cat "$list" 2>/dev/null)" = "$want" ]; then return 0; fi
  log "Legger til apt-repo $name."
  mkdir -p /etc/apt/keyrings
  curl -fsSL "$key_url" -o "$keyring.tmp"
  if grep -q -- "-----BEGIN PGP" "$keyring.tmp"; then
    gpg --dearmor --yes -o "$keyring" "$keyring.tmp"; rm -f "$keyring.tmp"
  else
    mv "$keyring.tmp" "$keyring"
  fi
  echo "$want" > "$list"
  rm -f "$KK_TMP/apt-updated"
}

apt_update_once() {
  [ -f "$KK_TMP/apt-updated" ] && return 0
  apt-get update -qq || log "apt-get update feilet, prøver likevel."
  touch "$KK_TMP/apt-updated"
}

# apt_install <pakke>...  installerer, eller oppgraderer hvis de finnes fra før
apt_install() {
  apt_update_once
  DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "$@" >/dev/null
}

pkg_version() { dpkg-query -W -f='${Version}' "$1" 2>/dev/null || echo mangler; }

# --- MultiMC (bruker) ---

# Skriver MultiMC-mappene til brukeren: mapper med instances/ og MultiMC-programmet,
# hvor som helst i hjemmemappa (f.eks. ~/MultiMC, ~/Nedlastinger/MultiMC, ~/.local/share/multimc)
multimc_dirs() {
  local inst d
  find "$HOME" -maxdepth 5 -type d -name instances \
       -not -path '*/.cache/*' -not -path '*/Trash/*' -not -path '*/.minecraft/*' 2>/dev/null |
  while IFS= read -r inst; do
    d=$(dirname "$inst")
    if [ -x "$d/MultiMC" ] || [ -x "$d/bin/MultiMC" ]; then echo "$d"; fi
  done | sort -u
}

# Skriver instansmappene (med mmc-pack.json), én per linje
multimc_instances() {
  local root inst
  while IFS= read -r root; do
    for inst in "$root"/instances/*/; do
      [ -f "$inst/mmc-pack.json" ] && echo "${inst%/}"
    done
  done < <(multimc_dirs)
  return 0
}

# instance_info <instansmappe>  ->  "<fabric|neoforge|-> <mc-versjon|->"
instance_info() {
  python3 -I - "$1/mmc-pack.json" <<'PY'
import json, sys
try:
    comps = {c["uid"]: c.get("version", "") for c in json.load(open(sys.argv[1]))["components"]}
except Exception:
    print("- -"); sys.exit()
mc = comps.get("net.minecraft") or "-"
loader = "fabric" if "net.fabricmc.fabric-loader" in comps else "neoforge" if "net.neoforged" in comps else "-"
print(loader, mc)
PY
}

# instance_mods_dir <instansmappe>
instance_mods_dir() {
  if [ -d "$1/minecraft" ] && [ ! -d "$1/.minecraft" ]; then echo "$1/minecraft/mods"; else echo "$1/.minecraft/mods"; fi
}
