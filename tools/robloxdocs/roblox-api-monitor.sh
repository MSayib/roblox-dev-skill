#!/usr/bin/env bash
# Compatibility entry point. The monitor is roblox-api-monitor.py — one implementation for
# macOS, Linux and Windows. This shim keeps `~/RobloxDocs/scripts/roblox-api-monitor.sh` working.
#
# Probe for a *working* Python: on Windows `python3` is often a Microsoft Store stub that fails.
set -euo pipefail
for py in ${ROBLOX_PYTHON:-} python3 python; do
    if command -v "$py" >/dev/null 2>&1 && \
       "$py" -c 'import sys; sys.exit(0 if sys.version_info >= (3, 6) else 1)' >/dev/null 2>&1; then
        exec "$py" "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/roblox-api-monitor.py" "$@"
    fi
done
echo "❌ Python 3.6+ is required (tried: ${ROBLOX_PYTHON:-} python3 python)" >&2
exit 1
