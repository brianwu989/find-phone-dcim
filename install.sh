#!/usr/bin/env bash
set -euo pipefail
TARGET="/usr/local/bin/find-phone-dcim"
cp -f "$(dirname "$0")/find_phone_dcim.sh" "$TARGET"
chmod +x "$TARGET"
echo "Installed to $TARGET"
echo "Usage: find-phone-dcim --dry-run --debug YYYY-MM-DD [OUTDIR]"
