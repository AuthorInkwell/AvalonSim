#!/usr/bin/env bash
set -euo pipefail

GODOT_VERSION="4.2-stable"
GODOT_URL="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/Godot_v${GODOT_VERSION}_linux.x86_64.zip"
GODOT_SHA512="6822394a1782d0bcfd3a69a047579d6bb3a0b7697697a02f45c4b487f7bfa12fda4c138ac35b36c956f59edd0fdbb8a0a4c8bde963471a66f44a28c4aa252ca3"
INSTALL_DIR="${HOME}/.local/bin"
INSTALL_PATH="${INSTALL_DIR}/godot"

if [[ -x "${INSTALL_PATH}" ]]; then
  exit 0
fi

mkdir -p "${INSTALL_DIR}"
tmpdir="$(mktemp -d)"
trap 'rm -rf "${tmpdir}"' EXIT

wget -q -O "${tmpdir}/godot.zip" "${GODOT_URL}"
printf '%s  %s\n' "${GODOT_SHA512}" "${tmpdir}/godot.zip" | sha512sum --check --status
unzip -qo "${tmpdir}/godot.zip" -d "${tmpdir}"
mv "${tmpdir}/Godot_v${GODOT_VERSION}_linux.x86_64" "${INSTALL_PATH}"
chmod +x "${INSTALL_PATH}"
