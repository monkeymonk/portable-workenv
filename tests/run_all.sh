#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
for script in step*.sh; do
  echo "=== $script ==="
  bash "$script"
done
echo "=== ALL STEPS PASS ==="
