#!/usr/bin/env bash
set -Eeuo pipefail

CONF_DIR=/etc/ssh/sshd_config.d
CONF_FILE="$CONF_DIR/00-key-only.conf"
BACKUP=""
TMP=""

if [[ $EUID -ne 0 ]]; then
  echo 'ERROR: Run this script with sudo or as root.' >&2
  exit 1
fi
if [[ ! -x /usr/sbin/sshd ]]; then
  echo 'ERROR: OpenSSH server is not installed.' >&2
  exit 1
fi
if [[ ! -f /etc/ssh/sshd_config ]]; then
  echo 'ERROR: Missing /etc/ssh/sshd_config.' >&2
  exit 1
fi

read -r -p 'Have you verified SSH public-key login in a separate session? [y/N] ' answer
if [[ ! "$answer" =~ ^[Yy]$ ]]; then
  echo 'Aborted. Set up and test your SSH key first.'
  exit 1
fi

install -d -m 755 "$CONF_DIR"
TMP=$(mktemp "$CONF_DIR/.key-only.XXXXXXXX")
cleanup() { [[ -z "$TMP" ]] || rm -f "$TMP"; }
trap cleanup EXIT

cat > "$TMP" <<'CONFIG'
# Managed by harden-ssh-key-only.sh
PubkeyAuthentication yes
PasswordAuthentication no
KbdInteractiveAuthentication no
AuthenticationMethods publickey
UsePAM yes
PermitRootLogin no
PermitEmptyPasswords no
MaxAuthTries 3
HostbasedAuthentication no
GSSAPIAuthentication no
CONFIG
chmod 644 "$TMP"

if [[ -e "$CONF_FILE" ]]; then
  BACKUP="${CONF_FILE}.bak.$(date -u +%Y%m%dT%H%M%SZ).$$"
  cp -a "$CONF_FILE" "$BACKUP"
  echo "Backup saved: $BACKUP"
fi

restore() {
  if [[ -n "$BACKUP" ]]; then
    cp -a "$BACKUP" "$CONF_FILE"
  else
    rm -f "$CONF_FILE"
  fi
}

mv -f "$TMP" "$CONF_FILE"
TMP=""

if ! /usr/sbin/sshd -t; then
  echo 'ERROR: SSH syntax validation failed; restoring previous configuration.' >&2
  restore
  exit 1
fi

# OpenSSH uses first-obtained values; verify that another earlier setting did not override ours.
settings=$(/usr/sbin/sshd -T)
for expected in \
  'pubkeyauthentication yes' \
  'passwordauthentication no' \
  'kbdinteractiveauthentication no' \
  'authenticationmethods publickey' \
  'permitrootlogin no' \
  'permitemptypasswords no' \
  'hostbasedauthentication no' \
  'gssapiauthentication no'; do
  if ! grep -Fxq "$expected" <<< "$settings"; then
    echo "ERROR: Effective SSH setting is not '$expected'; restoring previous configuration." >&2
    restore
    exit 1
  fi
done

if ! systemctl reload ssh; then
  echo 'ERROR: SSH reload failed; restoring previous configuration.' >&2
  restore
  systemctl reload ssh || true
  exit 1
fi

echo
echo 'SUCCESS: SSH key-only authentication configuration applied.'
echo "Configuration: $CONF_FILE"
echo "$settings" | grep -E '^(pubkeyauthentication|passwordauthentication|kbdinteractiveauthentication|authenticationmethods|permitrootlogin|permitemptypasswords|hostbasedauthentication|gssapiauthentication) '
echo
echo 'Keep this session open. Test a NEW SSH session using your private key.'
echo 'Note: Match blocks may override settings for particular users or source addresses.'
