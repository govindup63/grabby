#!/bin/bash
# Bundle, relaunch, and print the log command for the runtime checklist.
set -euo pipefail
cd "$(dirname "$0")/.."
scripts/bundle.sh
pkill -x Grabby || true
open build/Grabby.app
echo
echo "Watch logs with:"
echo "  log stream --predicate 'subsystem == \"com.pixelstwo.grabby\"' --level debug"
