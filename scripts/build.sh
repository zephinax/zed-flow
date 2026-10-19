#!/usr/bin/env bash
set -euo pipefail

# ZedFlow Build, Universal Packaging & Release Script

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="${ROOT_DIR}/ZedFlow.app"
DIST_DIR="${ROOT_DIR}/dist"
INSTALL=false
UNIVERSAL=false
PACKAGE_ZIP=false
VERSION="1.1.0"

for arg in "$@"; do
    case "$arg" in
        --install|-i)
            INSTALL=true
            ;;
        --universal|-u)
            UNIVERSAL=true
            ;;
        --zip|-z)
            PACKAGE_ZIP=true
            ;;
        --help|-h)
            echo "Usage: ./scripts/build.sh [options]"
            echo ""
            echo "Options:"
            echo "  --universal, -u  Build universal binary for Apple Silicon (arm64) and Intel (x86_64)"
            echo "  --zip, -z        Package release zip archive and SHA-256 checksum in dist/"
            echo "  --install, -i    Install ZedFlow.app to /Applications and symlink zedflow to PATH"
            echo "  --help, -h       Display this help message"
            exit 0
            ;;
    esac
done

TMP_BIN_DIR="/tmp/zedflow-build-$$"
APP_BIN_DIR="${TMP_BIN_DIR}/app"
CLI_BIN_DIR="${TMP_BIN_DIR}/cli"
mkdir -p "${APP_BIN_DIR}" "${CLI_BIN_DIR}"
trap "rm -rf '${TMP_BIN_DIR}'" EXIT

if [ "$UNIVERSAL" = true ]; then
    echo "🔨 Building ZedFlow universal binaries (arm64 + x86_64)..."
    swift build -c release --triple arm64-apple-macosx14.0 --package-path "${ROOT_DIR}"
    swift build -c release --triple x86_64-apple-macosx14.0 --package-path "${ROOT_DIR}"

    echo "🔗 Merging architectures using lipo..."
    lipo -create \
        "${ROOT_DIR}/.build/arm64-apple-macosx/release/ZedFlowApp" \
        "${ROOT_DIR}/.build/x86_64-apple-macosx/release/ZedFlowApp" \
        -output "${APP_BIN_DIR}/ZedFlow"

    lipo -create \
        "${ROOT_DIR}/.build/arm64-apple-macosx/release/zedflow" \
        "${ROOT_DIR}/.build/x86_64-apple-macosx/release/zedflow" \
        -output "${CLI_BIN_DIR}/zedflow"
    
    APP_BIN="${APP_BIN_DIR}/ZedFlow"
    CLI_BIN="${CLI_BIN_DIR}/zedflow"
else
    echo "🔨 Building ZedFlow in release mode..."
    swift build -c release --package-path "${ROOT_DIR}"
    cp "${ROOT_DIR}/.build/release/ZedFlowApp" "${APP_BIN_DIR}/ZedFlow"
    cp "${ROOT_DIR}/.build/release/zedflow" "${CLI_BIN_DIR}/zedflow"
    APP_BIN="${APP_BIN_DIR}/ZedFlow"
    CLI_BIN="${CLI_BIN_DIR}/zedflow"
fi

echo "📦 Assembling ZedFlow.app bundle..."
rm -rf "${APP_DIR}"
mkdir -p "${APP_DIR}/Contents/MacOS"
mkdir -p "${APP_DIR}/Contents/Resources"

echo -n "APPL????" > "${APP_DIR}/Contents/PkgInfo"
cp "${APP_BIN}" "${APP_DIR}/Contents/MacOS/ZedFlow"
cp "${ROOT_DIR}/Config/Info.plist" "${APP_DIR}/Contents/Info.plist"
if [ -f "${ROOT_DIR}/Config/AppIcon.icns" ]; then
    cp "${ROOT_DIR}/Config/AppIcon.icns" "${APP_DIR}/Contents/Resources/AppIcon.icns"
fi

# Ad-hoc sign bundle so macOS Gatekeeper allows execution
echo "✍️ Signing ZedFlow.app (ad-hoc)..."
codesign --force --deep --sign - "${APP_DIR}"
codesign --force --sign - "${CLI_BIN}" 2>/dev/null || true

echo "✅ Build complete! App located at: ${APP_DIR}"
echo "   CLI binary located at: ${CLI_BIN}"

if [ "$PACKAGE_ZIP" = true ]; then
    echo "🗜️ Packaging release archive..."
    mkdir -p "${DIST_DIR}"
    
    ARCH_TAG="universal"
    if [ "$UNIVERSAL" = false ]; then
        ARCH_TAG="$(uname -m)"
    fi
    
    ZIP_NAME="ZedFlow-v${VERSION}-macOS-${ARCH_TAG}.zip"
    ZIP_PATH="${DIST_DIR}/${ZIP_NAME}"
    
    rm -f "${ZIP_PATH}" "${ZIP_PATH}.sha256"
    
    # Bundle ZedFlow.app and standalone CLI binary into release archive
    (cd "${ROOT_DIR}" && zip -r -q -y "${ZIP_PATH}" "ZedFlow.app")
    (cd "${CLI_BIN_DIR}" && zip -u -q "${ZIP_PATH}" "zedflow")
    
    (cd "${DIST_DIR}" && shasum -a 256 "${ZIP_NAME}" > "${ZIP_NAME}.sha256")
    
    echo "📦 Release archive created: ${ZIP_PATH}"
    echo "   SHA256: $(cat "${ZIP_PATH}.sha256")"
fi

if [ "$INSTALL" = true ]; then
    echo "🚀 Installing to /Applications..."
    # Close running ZedFlow if active
    killall ZedFlow 2>/dev/null || true
    rm -rf /Applications/ZedFlow.app
    cp -R "${APP_DIR}" /Applications/ZedFlow.app

    CLI_TARGET="/usr/local/bin/zedflow"
    if [ ! -d "/usr/local/bin" ] || [ ! -w "/usr/local/bin" ]; then
        CLI_TARGET="${HOME}/.local/bin/zedflow"
        mkdir -p "${HOME}/.local/bin"
    fi

    echo "🔗 Installing CLI to ${CLI_TARGET}..."
    cp -f "${CLI_BIN}" "${CLI_TARGET}" || {
        echo "⚠️ Note: Could not copy CLI to ${CLI_TARGET}. You may need sudo, or add .build/release to PATH."
    }

    echo "🎉 Installation complete!"
fi
