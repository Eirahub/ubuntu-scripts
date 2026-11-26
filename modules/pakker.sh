# pakker: apt-pakkene kursene trenger (APT_PACKAGES i config.sh), installert og holdt oppdatert.
# Sjekker også at Bandit (Hackerskolen) kan nås på port 2220.

root_part() {
  # shellcheck disable=SC2086
  apt_install $APT_PACKAGES
  log "På plass: $(echo $APT_PACKAGES)"

  if [ -n "${BANDIT_CHECK:-}" ]; then
    if timeout 8 bash -c "</dev/tcp/${BANDIT_CHECK%:*}/${BANDIT_CHECK#*:}" 2>/dev/null; then
      log "Bandit ($BANDIT_CHECK) kan nås."
    else
      log "ADVARSEL: kommer ikke til $BANDIT_CHECK. Bandit i Hackerskolen virker ikke på dette nettet (port ${BANDIT_CHECK#*:} ut er stengt?)."
    fi
  fi
}
