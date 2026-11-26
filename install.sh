#!/usr/bin/env bash
# Installerer ubuntu-scripts på en laptop. Kjøres én gang:
#
#   curl -fsSL https://raw.githubusercontent.com/Eirahub/ubuntu-scripts/main/install.sh | sudo bash
#
# Fjern igjen:
#
#   curl -fsSL https://raw.githubusercontent.com/Eirahub/ubuntu-scripts/main/install.sh | sudo bash -s -- --avinstaller
set -euo pipefail

TARBALL="https://codeload.github.com/Eirahub/ubuntu-scripts/tar.gz/refs/heads/main"
DIR="/opt/ubuntu-scripts"
UNIT="/etc/systemd/system/ubuntu-scripts"

[ "$(id -u)" = 0 ] || { echo "Kjør med sudo."; exit 1; }

if [ "${1:-}" = --avinstaller ]; then
  [ -x "$DIR/run.sh" ] && "$DIR/run.sh" --avinstaller || true
  systemctl disable --now ubuntu-scripts.timer 2>/dev/null || true
  systemctl disable ubuntu-scripts-early.service 2>/dev/null || true
  rm -f "$UNIT.service" "$UNIT.timer" "$UNIT-early.service"
  systemctl daemon-reload
  rm -rf "$DIR"
  echo "Fjernet. Java, VS Code, Brave, MultiMC og mods er latt være. /etc/ubuntu-scripts og loggen er latt være."
  exit 0
fi

for cmd in curl python3 tar gpg; do
  command -v "$cmd" >/dev/null || { apt-get update -qq; apt-get install -y -qq curl python3 tar gpg; break; }
done

echo "Henter $TARBALL"
tmp=$(mktemp -d)
curl -fsSL "$TARBALL" -o "$tmp/repo.tgz"
mkdir -p "$tmp/new"
tar -xzf "$tmp/repo.tgz" -C "$tmp/new" --strip-components=1
rm -rf "$DIR"
mv "$tmp/new" "$DIR"
rm -rf "$tmp"
chmod 755 "$DIR/run.sh" "$DIR/install.sh"

mkdir -p /etc/ubuntu-scripts
if [ ! -f /etc/ubuntu-scripts/config.local.sh ]; then
  cat > /etc/ubuntu-scripts/config.local.sh <<'EOF'
# Innstillinger bare for denne laptopen. Overstyrer config.sh fra GitHub.
# Eksempler:
#   MODULES="pakker java vscode intellij multimc instance-java halisoncode keyring desktop"   # uten brave på denne
#   BRAVE_URL="https://example.org"
EOF
fi

cat > "$UNIT.service" <<EOF
[Unit]
Description=Kodeklubb: oppdater Java, VS Code, Brave, MultiMC og mods
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot
ExecStart=$DIR/run.sh
TimeoutStartSec=30min
EOF

cat > "$UNIT.timer" <<EOF
[Unit]
Description=Kodeklubb: oppdater ved oppstart og hver 6. time

[Timer]
OnBootSec=1min
OnUnitActiveSec=6h

[Install]
WantedBy=timers.target
EOF

# Rask kjøring uten nett før innloggingsskjermen (f.eks. nøkkelring, som må gjøres før innlogging)
cat > "$UNIT-early.service" <<EOF
[Unit]
Description=Kodeklubb: oppsett før innlogging
Before=display-manager.service systemd-user-sessions.service
After=local-fs.target

[Service]
Type=oneshot
ExecStart=$DIR/run.sh --tidlig
TimeoutStartSec=2min

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable ubuntu-scripts-early.service
systemctl enable --now ubuntu-scripts.timer
echo "Installert i $DIR. Kjører første gang nå (kan ta noen minutter)..."
systemctl start ubuntu-scripts.service || true
tail -n 40 /var/log/ubuntu-scripts.log
