# tailscale: Tailscale fra den offisielle apt-kilden, så laptopen kan nås hjemmefra (SSH, RustDesk).
# Logges inn én gang med TAILSCALE_AUTHKEY fra /etc/ubuntu-scripts/config.local.sh, aldri fra repoet.
# Er laptopen allerede innlogget, røres ingenting (tailscale up kjøres aldri på nytt med andre flagg).
# Slått av: Tailscale blir stående og innlogget, så fjerntilgangen ikke forsvinner. Ingen uninstall_part.

root_part() {
  local codename state key
  # Finnes Tailscale fra før (f.eks. som snap), brukes den. Ellers apt, som også holder den oppdatert.
  if [ -f /etc/apt/sources.list.d/tailscale.list ] || ! command -v tailscale >/dev/null; then
    # shellcheck source=/dev/null
    codename=$(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
    add_apt_repo tailscale "https://pkgs.tailscale.com/stable/ubuntu/$codename.noarmor.gpg" \
      "https://pkgs.tailscale.com/stable/ubuntu $codename main"
    apt_install tailscale
    systemctl enable --now tailscaled >/dev/null 2>&1 || true
    log "Tailscale: $(pkg_version tailscale)"
  fi

  state=$(tailscale status --json 2>/dev/null | python3 -I -c 'import json,sys; print(json.load(sys.stdin).get("BackendState",""))' 2>/dev/null || true)
  case "$state" in
    Running|Starting|Stopped) return 0 ;;   # innlogget (Stopped = noen har kjørt tailscale down med vilje)
  esac
  if [ -z "${TAILSCALE_AUTHKEY:-}" ]; then
    log "Tailscale er ikke innlogget, og TAILSCALE_AUTHKEY er ikke satt på denne laptopen (kjør install.sh med TAILSCALE_AUTHKEY=...)."
    return 0
  fi
  # Nøkkelen skrives til en fil bare root kan lese, så den ikke vises på kommandolinja
  key="$KK_TMP/tailscale-authkey"
  (umask 077; printf '%s' "$TAILSCALE_AUTHKEY" > "$key")
  if tailscale up --auth-key="file:$key" --hostname="$(hostname)" \
       ${TAILSCALE_TAGS:+--advertise-tags="$TAILSCALE_TAGS"} >/dev/null 2>&1; then
    log "Tailscale innlogget som $(hostname) ($(tailscale ip -4 2>/dev/null | head -n1))."
  else
    log "Tailscale-innlogging feilet. Sjekk at TAILSCALE_AUTHKEY er gyldig (og tillater taggene $TAILSCALE_TAGS)."
  fi
  rm -f "$key"
}
