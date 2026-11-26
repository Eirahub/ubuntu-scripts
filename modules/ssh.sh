# ssh: SSH-server der bare admin-kontoene (gruppen sudo) kan logge inn, og bare med nøklene i SSH_KEYS.
# Aldri passord, aldri root. Elevbrukeren kan ikke logge inn med SSH.

SSHD_CONF=/etc/ssh/sshd_config.d/50-ubuntu-scripts.conf

root_part() {
  local u home key changed=1
  apt_install openssh-server
  write_if_changed "$SSHD_CONF" "PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin no
AllowGroups sudo" && changed=0
  if ! sshd -t 2>/dev/null; then
    log "SSH-oppsettet ble ikke godtatt av sshd, fjerner det."; rm -f "$SSHD_CONF"; return 1
  fi

  while IFS= read -r u; do
    home=$(home_of "$u"); [ -d "$home" ] || continue
    install -d -m 700 -o "$u" -g "$u" "$home/.ssh"
    touch "$home/.ssh/authorized_keys"; chown "$u:$u" "$home/.ssh/authorized_keys"; chmod 600 "$home/.ssh/authorized_keys"
    while IFS= read -r key; do
      key=$(echo "$key" | xargs)
      [ -n "$key" ] || continue
      if ! grep -qF "$(echo "$key" | awk '{print $2}')" "$home/.ssh/authorized_keys"; then
        echo "$key" >> "$home/.ssh/authorized_keys"
        log "SSH-nøkkel lagt til for $u."
      fi
    done <<< "$SSH_KEYS"
  done < <(admin_users)

  # Ubuntu 24.04 starter sshd via ssh.socket, 22.04 via ssh.service
  if systemctl list-unit-files ssh.socket >/dev/null 2>&1 && systemctl cat ssh.socket >/dev/null 2>&1; then
    systemctl enable --now ssh.socket >/dev/null 2>&1 || true
  else
    systemctl enable --now ssh >/dev/null 2>&1 || true
  fi
  if [ "$changed" = 0 ]; then
    systemctl try-reload-or-restart ssh >/dev/null 2>&1 || true
    log "SSH: bare nøkkel, bare admin ($(admin_users | tr '\n' ' '))."
  fi
}

# Slått av: fjern vårt oppsett (serveren og nøklene blir stående)
uninstall_part() {
  if [ -f "$SSHD_CONF" ]; then
    rm -f "$SSHD_CONF"; systemctl try-reload-or-restart ssh >/dev/null 2>&1 || true
    log "Fjernet SSH-oppsettet."
  fi
}
