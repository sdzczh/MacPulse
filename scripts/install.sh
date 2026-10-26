#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="MacPulse"
SOURCE="$ROOT/dist/$APP_NAME.app"
TARGET="/Applications/$APP_NAME.app"

if [[ ! -w /Applications ]]; then
    echo "没有写入 /Applications 的权限，请确认当前账号属于 admin 组。" >&2
    exit 1
fi

echo "==> 打包"
"$ROOT/scripts/build-app.sh"

echo "==> 停止正在运行的实例"
if pgrep -x "$APP_NAME" >/dev/null 2>&1; then
    pkill -x "$APP_NAME" || true
    sleep 0.3
fi

echo "==> 安装到 $TARGET"
rm -rf "$TARGET"
ditto "$SOURCE" "$TARGET"
xattr -cr "$TARGET" 2>/dev/null || true

LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
if [[ -x "$LSREGISTER" ]]; then
    "$LSREGISTER" -f "$TARGET" || true
fi

echo "==> 完成，可从启动台打开 $APP_NAME（无 Dock 图标，启动后出现在菜单栏）。"
