#!/usr/bin/env bash
# Installs N GitHub Actions self-hosted runners on the current machine.
# Each runner is a separate process in its own directory.
#
# Required env:
#   DEMO_ORG       - throwaway org
#   DEMO_REPO      - repo name (default: cicd-demo)
#
# Optional env:
#   RUNNER_COUNT    - default: 10
#   RUNNER_VERSION  - default: 2.319.1 (check https://github.com/actions/runner/releases)
#   RUNNER_BASE     - default: ~/actions-runners
#   RUNNER_LABELS   - default: self-hosted,demo

set -euo pipefail

: "${DEMO_ORG:?set DEMO_ORG}"

DEMO_REPO="${DEMO_REPO:-cicd-demo}"
RUNNER_COUNT="${RUNNER_COUNT:-10}"
RUNNER_VERSION="${RUNNER_VERSION:-2.319.1}"
RUNNER_BASE="${RUNNER_BASE:-${HOME}/actions-runners}"
RUNNER_LABELS="${RUNNER_LABELS:-self-hosted,demo}"

# Detect OS / arch
OS="linux"
ARCH="x64"
case "$(uname -s)" in
  Darwin) OS="osx" ;;
  Linux)  OS="linux" ;;
  *) echo "Unsupported OS: $(uname -s)" >&2; exit 1 ;;
esac
case "$(uname -m)" in
  x86_64)          ARCH="x64" ;;
  arm64 | aarch64) ARCH="arm64" ;;
  *) echo "Unsupported arch: $(uname -m)" >&2; exit 1 ;;
esac

TARBALL="actions-runner-${OS}-${ARCH}-${RUNNER_VERSION}.tar.gz"
URL="https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/${TARBALL}"

mkdir -p "$RUNNER_BASE"
cd "$RUNNER_BASE"

if [ ! -f "$TARBALL" ]; then
  echo "[*] Downloading $TARBALL..."
  curl -fsSL -o "$TARBALL" "$URL"
fi

# Verify required tools are on PATH (runners need these for the demo workflow)
for tool in aws jq curl; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "WARNING: $tool not on PATH. Runner workflow will fail without it." >&2
    echo "         Install before starting runners." >&2
  fi
done

for i in $(seq 1 "$RUNNER_COUNT"); do
  RUNNER_DIR="${RUNNER_BASE}/runner-${i}"
  RUNNER_NAME="demo-runner-${i}"

  if [ -d "$RUNNER_DIR/.runner" ] 2>/dev/null || [ -f "$RUNNER_DIR/.runner" ]; then
    echo "[*] runner-${i} already configured, skipping"
    continue
  fi

  echo "[*] Installing runner-${i}..."
  mkdir -p "$RUNNER_DIR"
  tar -xzf "$TARBALL" -C "$RUNNER_DIR"

  echo "[*] Fetching registration token..."
  REG_TOKEN=$(gh api -X POST "repos/${DEMO_ORG}/${DEMO_REPO}/actions/runners/registration-token" --jq .token)

  echo "[*] Registering runner-${i}..."
  (
    cd "$RUNNER_DIR"
    ./config.sh \
      --url "https://github.com/${DEMO_ORG}/${DEMO_REPO}" \
      --token "$REG_TOKEN" \
      --name "$RUNNER_NAME" \
      --labels "$RUNNER_LABELS" \
      --work "_work" \
      --unattended \
      --replace
  )
done

echo ""
echo "[*] Installed ${RUNNER_COUNT} runners under ${RUNNER_BASE}"
echo "[*] Start them with: ./runner-pool/start-runners.sh"
