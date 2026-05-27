#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
# Glob expands lexicographically (step1, step10, step11, …, step2, …). Steps
# are independent but the numbering implies a narrative; sort numerically.
mapfile -t scripts < <(printf '%s\n' step*.sh | sort -V)
for script in "${scripts[@]}"; do
  echo "=== $script ==="
  bash "$script"
done
echo "=== ALL STEPS PASS ==="
