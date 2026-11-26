# vscode: Visual Studio Code fra Microsofts apt-repo (ikke flatpak/snap), installert og holdt oppdatert.

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
