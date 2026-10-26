#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

APP_NAME="MacPulse"
CONFIG="${BUILD_CONFIG:-release}"
DIST="$ROOT/dist"
APP="$DIST/$APP_NAME.app"

echo "==> 编译（$CONFIG）"
swift build -c "$CONFIG"
BIN_DIR="$(swift build -c "$CONFIG" --show-bin-path)"
BIN="$BIN_DIR/$APP_NAME"
if [[ ! -x "$BIN" ]]; then
    echo "找不到可执行文件：$BIN" >&2
    exit 1
fi

echo "==> 生成图标"
ICON="$ROOT/Resources/AppIcon.icns"
if [[ ! -f "$ICON" || "$ROOT/scripts/make-icon.swift" -nt "$ICON" ]]; then
    swift "$ROOT/scripts/make-icon.swift" "$ROOT/Resources"
fi

echo "==> 组装 .app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/$APP_NAME"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
if [[ -f "$ICON" ]]; then
    cp "$ICON" "$APP/Contents/Resources/AppIcon.icns"
fi
printf 'APPL????' > "$APP/Contents/PkgInfo"
chmod +x "$APP/Contents/MacOS/$APP_NAME"
xattr -cr "$APP" 2>/dev/null || true

echo "==> 本地 ad-hoc 签名"
codesign --force --deep --sign - --timestamp=none "$APP"
codesign --verify --verbose=1 "$APP"

echo "==> 完成：$APP"
