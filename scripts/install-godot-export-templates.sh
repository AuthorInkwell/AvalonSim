#!/usr/bin/env bash
set -euo pipefail

GODOT_VERSION="4.2-stable"
TEMPLATE_VERSION="4.2.stable"
TEMPLATE_URL="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/Godot_v${GODOT_VERSION}_export_templates.tpz"
TEMPLATE_SHA512="4ded511c4de93b6b536cafb9190b9563cf28a24033313aeaed2254d91ef2aad57f78143e97c28ecd0154b0ada9419512d15168deb3ecac4c2f7bbff02963a3c6"
INSTALL_DIR="${HOME}/.local/share/godot/export_templates/${TEMPLATE_VERSION}"

if [[ -f "${INSTALL_DIR}/web_release.zip" && -f "${INSTALL_DIR}/web_debug.zip" ]]; then
	exit 0
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "${tmpdir}"' EXIT

wget -q -O "${tmpdir}/templates.tpz" "${TEMPLATE_URL}"
printf '%s  %s\n' "${TEMPLATE_SHA512}" "${tmpdir}/templates.tpz" | sha512sum --check --status

mkdir -p "${INSTALL_DIR}"
unzip -joq \
	"${tmpdir}/templates.tpz" \
	"templates/version.txt" \
	"templates/web_debug.zip" \
	"templates/web_release.zip" \
	-d "${INSTALL_DIR}"
