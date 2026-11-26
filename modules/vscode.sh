# vscode: Visual Studio Code fra Microsofts apt-repo (ikke flatpak/snap), installert og holdt oppdatert.
# For hver bruker: utvidelsene i VSCODE_EXTENSIONS, ingen telemetri, ingen "stoler du på mappa?"-spørsmål.

root_part() {
  # Hindrer at code-pakken legger til sitt eget repo ved siden av vårt (gir "Conflicting values set for option Signed-By")
  echo "code code/add-microsoft-repo boolean false" | debconf-set-selections
  add_apt_repo vscode https://packages.microsoft.com/keys/microsoft.asc \
    "https://packages.microsoft.com/repos/code stable main"
  apt_install code
  log "VS Code: $(pkg_version code)"

  # Fjern flatpak- og snap-versjonen så elevene bare ser én (innstillinger i hjemmemappen blir liggende)
  if command -v flatpak >/dev/null && flatpak info com.visualstudio.code >/dev/null 2>&1; then
    flatpak uninstall -y --noninteractive com.visualstudio.code >/dev/null && log "Fjernet flatpak-versjonen."
  fi
  if command -v snap >/dev/null && snap list code >/dev/null 2>&1; then
    snap remove code >/dev/null && log "Fjernet snap-versjonen."
  fi
}

user_part() {
  command -v code >/dev/null || return 0
  local ext installed
  installed=$(code --list-extensions 2>/dev/null || true)
  for ext in $VSCODE_EXTENSIONS; do
    if ! grep -qix "$ext" <<< "$installed"; then
      if code --install-extension "$ext" --force >/dev/null 2>&1; then log "VS Code-utvidelse $ext installert."
      else log "Klarte ikke å installere VS Code-utvidelsen $ext."; fi
    fi
  done
  local out
  out=$(python3 -I - "$HOME/.config/Code/User/settings.json" <<'PY2'
import json, os, re, sys
path = sys.argv[1]
want = {
    "telemetry.telemetryLevel": "off",
    "security.workspace.trust.enabled": False,
    "update.mode": "none",
    "extensions.ignoreRecommendations": True,
    "workbench.startupEditor": "none",
}
data = {}
if os.path.exists(path):
    text = open(path).read()
    try:
        data = json.loads(text) if text.strip() else {}
    except ValueError:
        # VS Code tillater kommentarer og komma til slutt
        cleaned = re.sub(r"(?m)^\s*//.*$", "", text)
        cleaned = re.sub(r",(\s*[}\]])", r"\1", cleaned)
        try:
            data = json.loads(cleaned)
        except ValueError:
            print("ugyldig"); sys.exit()
if all(data.get(k) == v for k, v in want.items()):
    sys.exit()
data.update(want)
os.makedirs(os.path.dirname(path), exist_ok=True)
json.dump(data, open(path, "w"), indent=2)
print("endret")
PY2
)
  case "$out" in
    endret) log "VS Code-innstillinger satt." ;;
    ugyldig) log "Kunne ikke lese VS Code sin settings.json, lar den være." ;;
  esac
}
