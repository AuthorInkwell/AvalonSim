#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="${PROJECT_ROOT}/build/web"
GODOT_BIN="${GODOT_BIN:-godot}"

mkdir -p "${PROJECT_ROOT}/build"
touch "${PROJECT_ROOT}/build/.gdignore"
rm -rf "${OUTPUT_DIR}"
mkdir -p "${OUTPUT_DIR}"

"${GODOT_BIN}" \
	--headless \
	--path "${PROJECT_ROOT}" \
	--export-release Web \
	"${OUTPUT_DIR}/index.html"

cp "${PROJECT_ROOT}/web/coi-bootstrap.js" "${OUTPUT_DIR}/coi-bootstrap.js"
cp "${PROJECT_ROOT}/web/index.service.worker.js" "${OUTPUT_DIR}/index.service.worker.js"
cp -R "${PROJECT_ROOT}/web/playtest/." "${OUTPUT_DIR}/"

printf 'Avalon Web export written to %s\n' "${OUTPUT_DIR}"
