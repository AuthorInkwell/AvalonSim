#!/usr/bin/env bash
set -euo pipefail

GODOT_VERSION="4.2-stable"
GODOT_URL="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/Godot_v${GODOT_VERSION}_linux.x86_64.zip"
INSTALL_DIR="${HOME}/.local/bin"
INSTALL_PATH="${INSTALL_DIR}/godot"

if [[ -x "${INSTALL_PATH}" ]]; then
  exit 0
fi

mkdir -p "${INSTALL_DIR}"
tmpdir="$(mktemp -d)"
trap 'rm -rf "${tmpdir}"' EXIT

wget -q -O "${tmpdir}/godot.zip" "${GODOT_URL}"
unzip -qo "${tmpdir}/godot.zip" -d "${tmpdir}"
mv "${tmpdir}/Godot_v${GODOT_VERSION}_linux.x86_64" "${INSTALL_PATH}"
chmod +x "${INSTALL_PATH}"
