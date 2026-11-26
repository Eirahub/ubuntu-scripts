# instance-java: gir hver MultiMC-instans riktig Temurin-Java etter Minecraft-versjonen:
# 26.x -> 25, 1.20.5 til 1.21.x -> 21, 1.17 til 1.20.4 -> 17. Eldre versjoner røres ikke.

java_major_for() {
  python3 -I - "$1" <<'PY'
import sys
try:
    v = [int(x) for x in sys.argv[1].split(".")]
except ValueError:
    sys.exit()
if v[0] >= 26:          print(25)
elif v >= [1, 20, 5]:   print(21)
elif v >= [1, 17]:      print(17)
PY
}

java_path() {
  local p
  for p in /usr/lib/jvm/temurin-"$1"-"$JAVA_KIND"-*/bin/java /usr/lib/jvm/temurin-"$1"-*/bin/java; do
    if [ -x "$p" ]; then echo "$p"; return 0; fi
  done
}

# set_java <instance.cfg> <java-sti>: skriver "endret" hvis filen ble endret
set_java() {
  python3 -I - "$1" "$2" <<'PY'
import sys
path, java = sys.argv[1], sys.argv[2]
try:
    lines = open(path).read().splitlines()
except FileNotFoundError:
    lines = []
want = {"OverrideJavaLocation": "true", "JavaPath": java}
out, seen, changed = [], set(), False
for line in lines:
    key = line.split("=", 1)[0]
    if key in want:
        seen.add(key)
        if line != f"{key}={want[key]}":
            line, changed = f"{key}={want[key]}", True
    out.append(line)
for key in want:
    if key not in seen:
        out.append(f"{key}={want[key]}"); changed = True
if changed:
    open(path, "w").write("\n".join(out) + "\n")
    print("endret")
PY
}

user_part() {
  local inst name loader mc major jp
  while IFS= read -r inst; do
    name=$(basename "$inst")
    read -r loader mc < <(instance_info "$inst")
    [ "$mc" != "-" ] || continue
    major=$(java_major_for "$mc")
    [ -n "$major" ] || continue
    jp=$(java_path "$major")
    if [ -z "$jp" ]; then log "$name: Java $major er ikke installert."; continue; fi
    if [ -n "$(set_java "$inst/instance.cfg" "$jp")" ]; then log "$name: Java satt til $major."; fi
  done < <(multimc_instances)
}
