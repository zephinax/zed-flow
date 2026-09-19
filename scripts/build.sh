#!/usr/bin/env bash
set -euo pipefail

# ZedFlow Build & Packaging Script

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="${ROOT_DIR}/ZedFlow.app"
RELEASE_DIR="${ROOT_DIR}/.build/release"
INSTALL=false

for arg in "$@"; do
    case "$arg" in
        --install|-i)
            INSTALL=true
            ;;
        --help|-h)
            echo "Usage: ./scripts/build.sh [--install]"
            echo ""
            echo "Options:"
            echo "  --install, -i    Install ZedFlow.app to /Applications and symlink zedflow to /usr/local/bin"
            exit 0
            ;;
    esac
done

echo "🔨 Building ZedFlow in release mode..."
swift build -c release --package-path "${ROOT_DIR}"

echo "📦 Assembling ZedFlow.app bundle..."
mkdir -p "${APP_DIR}/Contents/MacOS"
mkdir -p "${APP_DIR}/Contents/Resources"

cp "${RELEASE_DIR}/ZedFlowApp" "${APP_DIR}/Contents/MacOS/ZedFlow"
cp "${ROOT_DIR}/Config/Info.plist" "${APP_DIR}/Contents/Info.plist"

# Ad-hoc sign bundle so macOS Gatekeeper allows execution
echo "✍️ Signing ZedFlow.app (ad-hoc)..."
codesign --force --deep --sign - "${APP_DIR}"

echo "✅ Build complete! App located at: ${APP_DIR}"
echo "   CLI binary located at: ${RELEASE_DIR}/zedflow"

if [ "$INSTALL" = true ]; then
    echo "🚀 Installing to /Applications..."
    # Close running ZedFlow if running
    killall ZedFlow 2>/dev/null || true
    rm -rf /Applications/ZedFlow.app
    cp -R "${APP_DIR}" /Applications/ZedFlow.app

    CLI_TARGET="/usr/local/bin/zedflow"
    if [ ! -d "/usr/local/bin" ]; then
        CLI_TARGET="${HOME}/.local/bin/zedflow"
        mkdir -p "${HOME}/.local/bin"
    fi

    echo "🔗 Symlinking CLI to ${CLI_TARGET}..."
    ln -sf "${RELEASE_DIR}/zedflow" "${CLI_TARGET}" || {
        echo "⚠️ Note: Could not create symlink at ${CLI_TARGET}. You may need sudo, or add .build/release to PATH."
    }

    echo "🎉 Installation complete!"
fi
