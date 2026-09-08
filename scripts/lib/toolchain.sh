# Shared toolchain selection and prerequisite checks for scripts/*.
# Source this file; do not execute it.
#
# Requirements (see ARCHITECTURE.md):
#   - Swift >= 6.2 (swift-tools-version 6.2 manifests, macOS 26 platform value)
#   - macOS SDK >= 26.0
#   - Command Line Tools are sufficient; full Xcode is not required.
#
# Set PRAXIS_DEVELOPER_DIR to use a specific developer directory for this
# command only (for example /Applications/Xcode.app/Contents/Developer) without
# changing the machine-wide xcode-select selection.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PRAXIS_MIN_SWIFT_MAJOR=6
PRAXIS_MIN_SWIFT_MINOR=2
PRAXIS_MIN_SDK_MAJOR=26
PRAXIS_BUNDLE_ID="com.villetakanen.praxis"

fail() {
    echo "error: $*" >&2
    exit 1
}

praxis_select_toolchain() {
    if [[ -n "${PRAXIS_DEVELOPER_DIR:-}" ]]; then
        [[ -d "$PRAXIS_DEVELOPER_DIR" ]] || fail "PRAXIS_DEVELOPER_DIR does not exist: $PRAXIS_DEVELOPER_DIR"
        export DEVELOPER_DIR="$PRAXIS_DEVELOPER_DIR"
    fi

    command -v xcrun >/dev/null 2>&1 \
        || fail "xcrun not found. Install Xcode or the Command Line Tools (xcode-select --install)."

    local developer_dir
    developer_dir="$(xcode-select -p 2>/dev/null)" \
        || fail "no active developer directory. Install the Command Line Tools or set PRAXIS_DEVELOPER_DIR."

    xcrun --find swift >/dev/null 2>&1 \
        || fail "swift not found in developer directory $developer_dir."

    local swift_version_line swift_version major minor
    swift_version_line="$(xcrun swift --version 2>/dev/null)"
    swift_version_line="${swift_version_line%%$'\n'*}"
    swift_version="$(sed -nE 's/.*Swift version ([0-9]+\.[0-9]+(\.[0-9]+)?).*/\1/p' <<<"$swift_version_line")"
    [[ -n "$swift_version" ]] || fail "could not parse Swift version from: $swift_version_line"
    major="${swift_version%%.*}"
    minor="$(cut -d. -f2 <<<"$swift_version")"
    if (( major < PRAXIS_MIN_SWIFT_MAJOR || (major == PRAXIS_MIN_SWIFT_MAJOR && minor < PRAXIS_MIN_SWIFT_MINOR) )); then
        fail "Swift $swift_version is older than the required $PRAXIS_MIN_SWIFT_MAJOR.$PRAXIS_MIN_SWIFT_MINOR."
    fi

    local sdk_version sdk_major
    sdk_version="$(xcrun --sdk macosx --show-sdk-version 2>/dev/null)" \
        || fail "macOS SDK not found in developer directory $developer_dir."
    sdk_major="${sdk_version%%.*}"
    (( sdk_major >= PRAXIS_MIN_SDK_MAJOR )) \
        || fail "macOS SDK $sdk_version is older than the required $PRAXIS_MIN_SDK_MAJOR.0."

    echo "toolchain: $developer_dir"
    echo "swift:     $swift_version_line"
    echo "sdk:       macOS $sdk_version"
}
