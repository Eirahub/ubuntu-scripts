# java: Eclipse Temurin (JAVA_VERSIONS) fra Adoptiums apt-repo, installert og holdt oppdatert.

root_part() {
  local codename v pkgs=()
  codename=$(. /etc/os-release; echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
  add_apt_repo adoptium https://packages.adoptium.net/artifactory/api/gpg/key/public \
    "https://packages.adoptium.net/artifactory/deb $codename main"
  for v in $JAVA_VERSIONS; do pkgs+=("temurin-$v-$JAVA_KIND"); done
  apt_install "${pkgs[@]}"
  for v in $JAVA_VERSIONS; do log "Java $v: $(pkg_version "temurin-$v-$JAVA_KIND")"; done
}
