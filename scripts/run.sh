#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/dist/MacPulse.app"

if pgrep -x MacPulse >/dev/null 2>&1; then
    pkill -x MacPulse || true
    sleep 0.3
fi

"$ROOT/scripts/build-app.sh"
open "$APP"
echo "MacPulse 已启动，请查看菜单栏右侧。"
