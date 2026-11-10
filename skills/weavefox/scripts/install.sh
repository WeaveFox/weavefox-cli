#!/usr/bin/env bash
#
# Install wf CLI for the current platform.
# Used by the weavefox skill so agents can bootstrap in one command.
#
set -euo pipefail

if command -v wf &> /dev/null; then
  echo "wf already installed: $(wf --version)"
  exit 0
fi

# Try npm first (works if Node.js is available)
if command -v npm &> /dev/null; then
  npm i -g @weavefox/cli
  echo "Installed via npm: $(wf --version)"
  exit 0
fi

# Fall back to standalone binary from GitHub Releases (checksum-verified)
OS=$(uname -s | tr 'A-Z' 'a-z')
ARCH=$(uname -m | sed 's/x86_64/x64/;s/aarch64/arm64/')
BASE_URL="https://github.com/weavefox/weavefox-cli/releases/latest/download"
ASSET="wf-${OS}-${ARCH}"

TMP_DIR=$(mktemp -d)
trap 'rm -rf "${TMP_DIR}"' EXIT

echo "Downloading ${ASSET} from GitHub Releases..."
curl -fsSL "${BASE_URL}/${ASSET}" -o "${TMP_DIR}/${ASSET}"
curl -fsSL "${BASE_URL}/checksums-sha256.txt" -o "${TMP_DIR}/checksums-sha256.txt"

EXPECTED=$( (grep "${ASSET}" "${TMP_DIR}/checksums-sha256.txt" | awk '{print $1}') || true )
if [ -z "${EXPECTED}" ]; then
  echo "Error: no checksum entry found for ${ASSET}" >&2
  exit 1
fi

if command -v sha256sum &> /dev/null; then
  ACTUAL=$(sha256sum "${TMP_DIR}/${ASSET}" | awk '{print $1}')
elif command -v shasum &> /dev/null; then
  ACTUAL=$(shasum -a 256 "${TMP_DIR}/${ASSET}" | awk '{print $1}')
else
  echo "Error: neither sha256sum nor shasum available; cannot verify download" >&2
  exit 1
fi

if [ "${ACTUAL}" != "${EXPECTED}" ]; then
  echo "Error: checksum mismatch for ${ASSET}" >&2
  echo "  expected: ${EXPECTED}" >&2
  echo "  actual:   ${ACTUAL}" >&2
  exit 1
fi

# Install to /usr/local/bin when writable, otherwise ~/.local/bin
if [ -w /usr/local/bin ] || [ "$(id -u)" = "0" ]; then
  TARGET_DIR="/usr/local/bin"
else
  TARGET_DIR="${HOME}/.local/bin"
  mkdir -p "${TARGET_DIR}"
  case ":${PATH}:" in
    *":${TARGET_DIR}:"*) ;;
    *)
      echo "Note: ${TARGET_DIR} is not on PATH. Add it to use 'wf' directly:" >&2
      echo "  export PATH=\"${TARGET_DIR}:\$PATH\"" >&2
      ;;
  esac
fi

install -m 0755 "${TMP_DIR}/${ASSET}" "${TARGET_DIR}/wf"
echo "Installed binary: ${TARGET_DIR}/wf"
"${TARGET_DIR}/wf" --version
