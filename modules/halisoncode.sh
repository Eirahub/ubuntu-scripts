# halisoncode: siste Halison Code-mod fra GitHub (og Fabric API fra Modrinth) i MultiMC-instansene.
# Får moden: instanser som har halisoncode-*.jar eller codeling-*.jar fra før,
# og instanser med HALISON_INSTANCE_MATCH i navnet. Instansen må ha Fabric eller NeoForge.

# Minecraft-versjon -> jar-target. Holdes i takt med scripts/setup-multimc.ps1 i mod-repoet.
target_for() {
  case "$1" in
    1.21|1.21.1)          echo 1.21.1 ;;
    1.21.2|1.21.3)        echo 1.21.3 ;;
    1.21.4)               echo 1.21.4 ;;
    1.21.5)               echo 1.21.5 ;;
    1.21.6|1.21.7|1.21.8) echo 1.21.8 ;;
    1.21.9|1.21.10)       echo 1.21.10 ;;
    1.21.11)              echo 1.21.11 ;;
    26.1|26.1.1|26.1.2)   echo 26.1.2 ;;
    *)                    echo "$1" ;;
  esac
}

load_releases() {
  [ -f "$KK_TMP/releases.json" ] && return 0
  curl -fsSL -A "$UA" "https://api.github.com/repos/$HALISON_REPO/releases?per_page=10" -o "$KK_TMP/releases.json"
}

# pick_release <loader> <target> -> "<tag> <jar-url> <sums-url>" eller "- - -"
pick_release() {
  python3 -I - "$KK_TMP/releases.json" "$1" "$2" "$HALISON_PRERELEASE" <<'PY'
import json, re, sys
releases, loader, target, pre = json.load(open(sys.argv[1])), sys.argv[2], sys.argv[3], sys.argv[4] == "1"
pat = re.compile(rf"^halisoncode-{re.escape(loader)}-{re.escape(target)}-[^-]+\.jar$")
for r in releases:
    if r.get("draft") or (r.get("prerelease") and not pre):
        continue
    jar = next((a for a in r["assets"] if pat.match(a["name"])), None)
    if jar:
        sums = next((a for a in r["assets"] if a["name"] == "SHA256SUMS"), None)
        print(r["tag_name"], jar["browser_download_url"], sums["browser_download_url"] if sums else "-")
        break
else:
    print("- - -")
PY
}

update_mod() {  # <mods-mappe> <loader> <mc-versjon> <navn>
  local dir=$1 loader=$2 mc=$3 name=$4 tag url sums jar want
  read -r tag url sums < <(pick_release "$loader" "$(target_for "$mc")")
  if [ "$tag" = "-" ]; then log "$name: ingen Halison Code-jar for $loader $mc."; return 0; fi
  jar=$(basename "$url")
  if [ -f "$dir/$jar" ]; then log "$name: Halison Code $tag er på plass."; return 0; fi
  if [ ! -f "$KK_TMP/$jar" ]; then
    curl -fsSL -A "$UA" "$url" -o "$KK_TMP/$jar"
    if [ "$sums" != "-" ]; then
      [ -f "$KK_TMP/SHA256SUMS.$tag" ] || curl -fsSL -A "$UA" "$sums" -o "$KK_TMP/SHA256SUMS.$tag"
      want=$(grep -E "[ *]$jar\$" "$KK_TMP/SHA256SUMS.$tag" | cut -d' ' -f1 || true)
      if [ "$(sha256sum "$KK_TMP/$jar" | cut -d' ' -f1)" != "$want" ]; then
        log "$name: sjekksum feilet for $jar, hopper over."; rm -f "$KK_TMP/$jar"; return 0
      fi
    fi
  fi
  find "$dir" -maxdepth 1 -type f \( -name 'halisoncode-*.jar' -o -name 'codeling-*.jar' \) -delete
  cp "$KK_TMP/$jar" "$dir/"
  log "$name: installerte $jar ($tag)."
}

update_fabric_api() {  # <mods-mappe> <mc-versjon> <navn>
  local dir=$1 mc=$2 name=$3 fname furl fsha cache="$KK_TMP/fapi-$2.json"
  if [ ! -f "$cache" ]; then
    if ! curl -fsSL -A "$UA" -G "https://api.modrinth.com/v2/project/fabric-api/version" \
         --data-urlencode 'loaders=["fabric"]' --data-urlencode "game_versions=[\"$mc\"]" -o "$cache"; then
      log "$name: fikk ikke kontakt med Modrinth, hopper over Fabric API."; rm -f "$cache"; return 0
    fi
  fi
  read -r fname furl fsha < <(python3 -I - "$cache" <<'PY'
import json, sys
v = json.load(open(sys.argv[1]))
if not v:
    print("- - -")
else:
    f = next((f for f in v[0]["files"] if f["primary"]), v[0]["files"][0])
    print(f["filename"], f["url"], f["hashes"]["sha512"])
PY
)
  if [ "$fname" = "-" ]; then log "$name: ingen Fabric API for $mc."; return 0; fi
  [ -f "$dir/$fname" ] && return 0
  if [ ! -f "$KK_TMP/$fname" ]; then
    curl -fsSL -A "$UA" "$furl" -o "$KK_TMP/$fname"
    if [ "$(sha512sum "$KK_TMP/$fname" | cut -d' ' -f1)" != "$fsha" ]; then
      log "$name: sjekksum feilet for $fname, hopper over."; rm -f "$KK_TMP/$fname"; return 0
    fi
  fi
  find "$dir" -maxdepth 1 -type f -name 'fabric-api-*.jar' -delete
  cp "$KK_TMP/$fname" "$dir/"
  log "$name: installerte $fname."
}

user_part() {
  local inst name mods has loader mc
  while IFS= read -r inst; do
    name=$(basename "$inst")
    mods=$(instance_mods_dir "$inst")
    has=$(find "$mods" -maxdepth 1 -type f \( -name 'halisoncode-*.jar' -o -name 'codeling-*.jar' \) 2>/dev/null | head -n1)
    if [ -z "$has" ] && { [ -z "$HALISON_INSTANCE_MATCH" ] || [[ "$name" != *"$HALISON_INSTANCE_MATCH"* ]]; }; then
      continue
    fi
    read -r loader mc < <(instance_info "$inst")
    if [ "$loader" = "-" ] || [ "$mc" = "-" ]; then
      log "$name: har ikke Fabric eller NeoForge, kan ikke legge inn Halison Code."; continue
    fi
    if ! load_releases; then log "Fikk ikke kontakt med GitHub, hopper over."; return 0; fi
    mkdir -p "$mods"
    update_mod "$mods" "$loader" "$mc" "$name"
    if [ "$loader" = fabric ] && [ "$HALISON_FABRIC_API" = 1 ]; then update_fabric_api "$mods" "$mc" "$name"; fi
  done < <(multimc_instances)
}
