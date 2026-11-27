# hackerlab: Hackerskolen (oppgaver.eirahub.no/hackerskolen) ferdig satt opp for elevbrukeren.
#   - Laben (HACKERLAB_ZIP) i ~/hackerlab, og i /etc/skel så den kommer tilbake etter nullstilling
#   - Kiosken og den hemmelige tjenesten starter ved innlogging, som elevbrukeren (systemd --user)
#   - Kiosken startes på nytt når eleven lagrer kiosk.py
#   - Caddy på port 80: http://HACKERLAB_HOST -> Kiosken på 127.0.0.1:8080, med en forklaring når den
#     ikke svarer. Caddy lytter bare på maskinen selv, så ingen andre på nettet når Kiosken.
# Kiosken er sårbar med vilje og ligger der eleven kan endre den. Den skal ALDRI kjøre som root.
# Fremgangen følger eleven, ikke laptopen: python3 sjekk.py status viser en fremgangskode.
# Slått av: tjenestene, Caddy-oppsettet og laben i /etc/skel fjernes. Caddy og ~/hackerlab blir stående.

LAB_SRC=/usr/local/share/hackerlab
LAB_SKEL=/etc/skel/hackerlab
UNIT_DIR=/etc/systemd/user
CADDYFILE=/etc/caddy/Caddyfile
ENABLE="kiosken.service kiosken-omstart.path hemmelig-tjeneste.service"
UNITS="$ENABLE kiosken-omstart.service"

caddyfile() {
  cat <<EOF
# Laget av ubuntu-scripts (modules/hackerlab.sh). Endringer her blir overskrevet.
{
	admin off
	default_bind 127.0.0.1 [::1]
}

http://$HACKERLAB_HOST {
	reverse_proxy 127.0.0.1:8080
	handle_errors {
		header Content-Type "text/plain; charset=utf-8"
		respond <<TEKST
			Kiosken svarer ikke.
			
			Har du endret kiosk.py? Da har du kanskje en feil i koden.
			Åpne en terminal og skriv:
			
			  cd ~/hackerlab
			  python3 kiosk.py
			
			Da ser du feilmeldingen og hvilken linje den gjelder.
			Rett feilen og lagre, så starter Kiosken av seg selv.
			TEKST 502
	}
}

http://${HACKERLAB_HOST#www.} {
	redir http://$HACKERLAB_HOST{uri}
}
EOF
}

# Brukertjenestene. ConditionUser: bare elevbrukeren, ikke admin-kontoene.
unit_kiosken() {
  cat <<EOF
[Unit]
Description=Hackerskolen: Kiosken på http://$HACKERLAB_HOST
ConditionUser=$ELEV_USER
ConditionPathExists=%h/hackerlab/kiosk.py
StartLimitIntervalSec=0

[Service]
WorkingDirectory=%h/hackerlab
Environment=PYTHONUTF8=1 PYTHONUNBUFFERED=1 KIOSK_URL=http://$HACKERLAB_HOST
ExecStart=/usr/bin/python3 %h/hackerlab/kiosk.py
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
EOF
}

unit_omstart_path() {
  cat <<EOF
[Unit]
Description=Hackerskolen: start Kiosken på nytt når kiosk.py lagres
ConditionUser=$ELEV_USER

[Path]
PathChanged=%h/hackerlab/kiosk.py
Unit=kiosken-omstart.service

[Install]
WantedBy=default.target
EOF
}

unit_omstart_service() {
  cat <<EOF
[Unit]
Description=Hackerskolen: start Kiosken på nytt

[Service]
Type=oneshot
ExecStart=/usr/bin/systemctl --user restart kiosken.service
EOF
}

unit_hemmelig() {
  cat <<EOF
[Unit]
Description=Hackerskolen: en tjeneste på en hemmelig port
ConditionUser=$ELEV_USER
ConditionPathExists=%h/hackerlab/hemmelig_tjeneste.py

[Service]
WorkingDirectory=%h/hackerlab
Environment=PYTHONUTF8=1 PYTHONUNBUFFERED=1
ExecStart=/usr/bin/python3 %h/hackerlab/hemmelig_tjeneste.py
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
EOF
}

# Henter laben og legger den i LAB_SRC og /etc/skel hvis den er ny
update_lab() {
  local zip="$KK_TMP/hackerlab.zip" new="$KK_TMP/hackerlab-ny" f
  if ! curl -fsSL --max-time 60 -A "$UA" "$HACKERLAB_ZIP" -o "$zip" || ! unzip -tq "$zip" >/dev/null 2>&1; then
    log "Fikk ikke hentet laben fra $HACKERLAB_ZIP, bruker den jeg har."; return 0
  fi
  mkdir -p "$new" && unzip -q "$zip" -d "$new"
  for f in kiosk.py sjekk.py lag_oppdrag.py hemmelig_tjeneste.py; do
    [ -f "$new/hackerlab/$f" ] || { log "Laben fra $HACKERLAB_ZIP mangler $f, bruker den jeg har."; return 0; }
  done
  if diff -rq "$new/hackerlab" "$LAB_SRC" >/dev/null 2>&1 && diff -rq "$new/hackerlab" "$LAB_SKEL" >/dev/null 2>&1; then
    return 0
  fi
  chown -R root:root "$new/hackerlab"
  find "$new/hackerlab" -type d -exec chmod 755 {} + && find "$new/hackerlab" -type f -exec chmod 644 {} +
  rm -rf "$LAB_SRC" "$LAB_SKEL"
  cp -a "$new/hackerlab" "$LAB_SRC"
  cp -a "$new/hackerlab" "$LAB_SKEL"
  log "Laben er oppdatert ($LAB_SRC og $LAB_SKEL)."
}

root_part() {
  local changed=1 home

  # Caddy fra den offisielle apt-kilden. --force-confold: behold vår Caddyfile ved oppgradering.
  if [ -f /etc/apt/sources.list.d/caddy.list ] || ! command -v caddy >/dev/null; then
    add_apt_repo caddy https://dl.cloudsmith.io/public/caddy/stable/gpg.key \
      "https://dl.cloudsmith.io/public/caddy/stable/deb/debian any-version main"
    apt_install -o Dpkg::Options::=--force-confold caddy
    log "Caddy: $(pkg_version caddy)"
  fi
  if write_if_changed "$CADDYFILE" "$(caddyfile)"; then
    log "Caddyfile oppdatert: http://$HACKERLAB_HOST -> 127.0.0.1:8080"; changed=0
  fi
  # admin off: "systemctl reload caddy" virker ikke, så den startes på nytt ved endring
  systemctl enable caddy >/dev/null 2>&1 || true
  if [ "$changed" = 0 ] || ! systemctl is-active --quiet caddy; then
    systemctl restart caddy || log "Caddy startet ikke. Se: journalctl -u caddy"
  fi

  update_lab

  # Elevbrukeren: legg inn laben hvis den mangler. Finnes den, røres den ikke (eleven kan ha
  # rettet kiosk.py). Ny versjon kommer med nullstillingen, fra /etc/skel.
  home=$(home_of "$ELEV_USER")
  if [ -n "$home" ] && [ -d "$home" ] && [ -d "$LAB_SRC" ] && [ ! -e "$home/hackerlab" ]; then
    cp -a "$LAB_SRC" "$home/hackerlab"
    chown -R "$ELEV_USER:$ELEV_USER" "$home/hackerlab"
    log "La inn laben i $home/hackerlab."
  fi

  # Brukertjenestene, slått på for alle brukere (ConditionUser begrenser til elevbrukeren)
  mkdir -p "$UNIT_DIR"
  changed=1
  write_if_changed "$UNIT_DIR/kiosken.service" "$(unit_kiosken)" && changed=0
  write_if_changed "$UNIT_DIR/kiosken-omstart.path" "$(unit_omstart_path)" && changed=0
  write_if_changed "$UNIT_DIR/kiosken-omstart.service" "$(unit_omstart_service)" && changed=0
  write_if_changed "$UNIT_DIR/hemmelig-tjeneste.service" "$(unit_hemmelig)" && changed=0
  # shellcheck disable=SC2086
  systemctl --global enable $ENABLE >/dev/null 2>&1 || true

  # Er elevbrukeren innlogget (automatisk innlogging), startes tjenestene i den økta med en gang
  if [ "$changed" = 0 ] && systemctl is-active --quiet "user@$(id -u "$ELEV_USER" 2>/dev/null).service" 2>/dev/null; then
    systemctl --user -M "$ELEV_USER@" daemon-reload >/dev/null 2>&1 || true
    # shellcheck disable=SC2086
    systemctl --user -M "$ELEV_USER@" restart $ENABLE >/dev/null 2>&1 || true
    log "Tjenestene er startet for $ELEV_USER."
  elif [ "$changed" = 0 ]; then
    log "Tjenestene starter ved neste innlogging som $ELEV_USER."
  fi
  return 0
}

# Slått av: ingen sårbar nettside eller tjenester på laptopen når kurset ikke går
uninstall_part() {
  local u found=1
  for u in $UNITS; do [ -f "$UNIT_DIR/$u" ] && found=0; done
  if [ "$found" = 0 ]; then
    # shellcheck disable=SC2086
    systemctl --global disable $ENABLE >/dev/null 2>&1 || true
    if id "$ELEV_USER" >/dev/null 2>&1; then
      # shellcheck disable=SC2086
      systemctl --user -M "$ELEV_USER@" stop $UNITS >/dev/null 2>&1 || true
    fi
    for u in $UNITS; do rm -f "$UNIT_DIR/$u"; done
    log "Fjernet Kiosken og den hemmelige tjenesten."
  fi
  if grep -qs "modules/hackerlab.sh" "$CADDYFILE"; then
    systemctl disable --now caddy >/dev/null 2>&1 || true
    rm -f "$CADDYFILE"
    log "Caddy stoppet og Caddyfile fjernet (Caddy er fortsatt installert)."
  fi
  if [ -d "$LAB_SKEL" ] || [ -d "$LAB_SRC" ]; then
    rm -rf "$LAB_SKEL" "$LAB_SRC"
    log "Fjernet laben fra /etc/skel (~/hackerlab hos brukerne blir stående)."
  fi
  return 0
}
