#!/usr/bin/env bash
# Additional OpenSSH hardening for Ubuntu 24.04 LTS.
# Does not change authentication policy or UFW.
set -Eeuo pipefail

CONFIG='/etc/ssh/sshd_config.d/01-security.conf'
BACKUP=''

if (( EUID != 0 )); then
  echo 'Error: run this script with sudo or as root.' >&2
  exit 1
fi

if ! command -v sshd >/dev/null 2>&1 && [[ ! -x /usr/sbin/sshd ]]; then
  echo 'Error: OpenSSH server is not installed.' >&2
  exit 1
fi
SSHD=$(command -v sshd || echo /usr/sbin/sshd)

if ! systemctl is-active --quiet ssh.service; then
  echo 'Error: ssh.service is not active. No changes made.' >&2
  exit 1
fi

cat <<'NOTICE'
This script restricts SSH forwarding (including TCP, Unix socket, agent,
and X11 forwarding). This can break VS Code Remote SSH, SSH tunnels,
remote development workflows, and other forwarding-dependent tools.

Keep an existing SSH session and Proxmox console access available.
NOTICE
read -r -p 'Apply these SSH hardening settings? [y/N] ' answer
if [[ ! "$answer" =~ ^[Yy]$ ]]; then
  echo 'Cancelled; no changes made.'
  exit 0
fi

mkdir -p /etc/ssh/sshd_config.d
if [[ -e "$CONFIG" ]]; then
  BACKUP="${CONFIG}.bak.$(date -u +%Y%m%dT%H%M%SZ).$$"
  cp -a -- "$CONFIG" "$BACKUP"
  echo "Backup created: $BACKUP"
fi

restore() {
  if [[ -n "$BACKUP" ]]; then
    cp -a -- "$BACKUP" "$CONFIG"
  else
    rm -f -- "$CONFIG"
  fi
}

TMP=$(mktemp /etc/ssh/sshd_config.d/.01-security.XXXXXXXX)
trap 'rm -f -- "$TMP"' EXIT
cat > "$TMP" <<'SETTINGS'
# Additional SSH hardening - managed by harden-ssh-additional.sh
LoginGraceTime 30
MaxStartups 10:30:60
ClientAliveInterval 300
ClientAliveCountMax 2
X11Forwarding no
AllowAgentForwarding no
AllowTcpForwarding no
AllowStreamLocalForwarding no
PermitTunnel no
SETTINGS
chmod 0644 "$TMP"
chown root:root "$TMP"
mv -f -- "$TMP" "$CONFIG"

if ! "$SSHD" -t; then
  echo 'SSH syntax validation failed. Restoring previous configuration.' >&2
  restore
  exit 1
fi

# Ubuntu's sshd_config includes the drop-in directory early, but another
# earlier drop-in or Match block may override some effective values.
echo 'Effective global SSH settings:'
"$SSHD" -T | grep -Ei '^(logingracetime|maxstartups|clientaliveinterval|clientalivecountmax|x11forwarding|allowagentforwarding|allowtcpforwarding|allowstreamlocalforwarding|permittunnel) ' || true

if ! systemctl reload ssh.service; then
  echo 'SSH reload failed. Restoring previous configuration.' >&2
  restore
  "$SSHD" -t && systemctl reload ssh.service || true
  exit 1
fi

echo 'SSH configuration validated and reloaded successfully.'
echo 'Test a NEW SSH session before closing your existing session.'
