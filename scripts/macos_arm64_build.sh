#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
BOOTSTRAP="${SOURCE_DIR}/bootStrapMacOS_Monterey.arm64.sh"

fail() {
    echo "Error: $*" >&2
    exit 1
}

[[ "$(uname -s)" == "Darwin" ]] || fail "This build must run on macOS."
[[ "$(uname -m)" == "arm64" ]] || fail "Run this script natively on an Apple Silicon Mac."

BUILD_ROOT="${ADM_BUILD_ROOT:-${PWD}}"
[[ -d "$BUILD_ROOT" ]] || fail "Build directory does not exist: $BUILD_ROOT"

case_dir="${BUILD_ROOT}/.avidemux-case-check"
mkdir -p "$case_dir"
: > "${case_dir}/CaseProbe"
if [[ -e "${case_dir}/caseprobe" ]]; then
    rm -rf "$case_dir"
    fail "Build directory must be on a case-sensitive volume. Set ADM_BUILD_ROOT to a case-sensitive APFS volume."
fi
rm -rf "$case_dir"

for tool in cmake ninja make yasm pkg-config qmake; do
    command -v "$tool" >/dev/null 2>&1 || fail "Missing build tool: $tool"
done

HOST_MACOS_TARGET="$(sw_vers -productVersion | awk -F. '{print $1 ".0"}')"
export ADM_MACOSX_DEPLOYMENT_TARGET="${ADM_MACOSX_DEPLOYMENT_TARGET:-${HOST_MACOS_TARGET}}"
export ADM_BUILD_JOBS="${ADM_BUILD_JOBS:-$(sysctl -n hw.logicalcpu)}"
export ADM_LOG_DIR="${ADM_LOG_DIR:-${SOURCE_DIR}/buildlogs/macos-arm64}"
mkdir -p "$ADM_LOG_DIR"

echo "Source: $SOURCE_DIR"
echo "Build:  $BUILD_ROOT"
echo "Qt:     $(qmake -query QT_VERSION) at $(qmake -query QT_INSTALL_PREFIX)"
echo "Target: arm64 / macOS ${ADM_MACOSX_DEPLOYMENT_TARGET}"
echo "Jobs:   $ADM_BUILD_JOBS"
echo "Logs:   $ADM_LOG_DIR"

cd "$BUILD_ROOT"
bash "$BOOTSTRAP" --with-internal-liba52 "$@" 2>&1 | tee "${ADM_LOG_DIR}/bootstrap.log"

DIST_DIR="${ADM_DIST_DIR:-${SOURCE_DIR}/dist}"
APP_BUNDLE="${BUILD_ROOT}/installer/Avidemux Mac.app"
DMG_FILE="$(find "${BUILD_ROOT}/installer" -maxdepth 1 -type f -name 'Avidemux Mac*.dmg' -print -quit)"
if [[ -d "$APP_BUNDLE" ]]; then
    ADM_MACOSX_DEPLOYMENT_TARGET="$ADM_MACOSX_DEPLOYMENT_TARGET" \
        "${SOURCE_DIR}/scripts/verify_macos_bundle.sh" "$APP_BUNDLE"
    mkdir -p "$DIST_DIR"
    rm -rf "${DIST_DIR}/Avidemux Mac.app"
    ditto "$APP_BUNDLE" "${DIST_DIR}/Avidemux Mac.app"
fi
if [[ -n "$DMG_FILE" ]]; then
    mkdir -p "$DIST_DIR"
    cp -f "$DMG_FILE" "$DIST_DIR/"
fi
echo "Artifacts copied to: $DIST_DIR"
