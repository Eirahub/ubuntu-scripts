# wifi: kurs-nettet WIFI_SSID er lagret for alle brukere og kobler til automatisk, også før innlogging,
# så elevbrukeren og oppdateringene ved oppstart alltid har nett.
# Passordet ligger ALDRI i repoet. Det hentes fra tilkoblingen som allerede er lagret på laptopen, eller fra
# WIFI_PASSWORD i /etc/ubuntu-scripts/config.local.sh.

root_part() {
  [ -n "${WIFI_SSID:-}" ] || return 0
  command -v nmcli >/dev/null || { log "NetworkManager mangler, hopper over."; return 0; }
  local con psk perms flags
  # Lagret tilkobling for nettet (navnet kan være forskjellig fra SSID-en)
  con=$(nmcli -t -f NAME,TYPE connection show | awk -F: '$2=="802-11-wireless"{print $1}' | while IFS= read -r c; do
          [ "$(nmcli -g 802-11-wireless.ssid connection show "$c" 2>/dev/null)" = "$WIFI_SSID" ] && { echo "$c"; break; }
        done)
  if [ -n "$con" ]; then
    psk=$(nmcli -s -g 802-11-wireless-security.psk connection show "$con" 2>/dev/null || true)
    psk=${psk:-${WIFI_PASSWORD:-}}
    perms=$(nmcli -g connection.permissions connection show "$con")
    flags=$(nmcli -g 802-11-wireless-security.psk-flags connection show "$con")
    if [ -n "$perms" ] || [ "${flags%% *}" != "0" ]; then
      if [ -z "$psk" ]; then
        log "ADVARSEL: passordet til $WIFI_SSID er lagret hos én bruker. Sett WIFI_PASSWORD i /etc/ubuntu-scripts/config.local.sh."
        return 0
      fi
      # Endringen kobler ikke fra nettet; den gjelder fra neste tilkobling
      nmcli connection modify "$con" connection.permissions "" 802-11-wireless-security.psk-flags 0 \
        802-11-wireless-security.psk "$psk" connection.autoconnect yes
      log "Wifi $WIFI_SSID er nå tilgjengelig for alle brukere, også før innlogging."
    fi
  elif [ -n "${WIFI_PASSWORD:-}" ]; then
    nmcli connection add type wifi con-name "$WIFI_SSID" ssid "$WIFI_SSID" \
      802-11-wireless-security.key-mgmt wpa-psk 802-11-wireless-security.psk "$WIFI_PASSWORD" \
      connection.permissions "" connection.autoconnect yes >/dev/null
    log "Wifi $WIFI_SSID lagt til for alle brukere."
  else
    log "Wifi $WIFI_SSID er ikke lagret her. Koble til én gang, eller sett WIFI_PASSWORD i /etc/ubuntu-scripts/config.local.sh."
  fi
}
