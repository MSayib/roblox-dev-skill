#!/usr/bin/env bash
# Compatibility shim. The splitter is now split-api-dump.py (one Python pass, no jq).
# Kept so existing references to split-api-dump.sh keep working.
set -euo pipefail
exec python3 "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/split-api-dump.py" "$@"
