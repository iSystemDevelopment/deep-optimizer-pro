#!/bin/bash
# Minimal self-check: syntax + help/version (no root changes)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

# Ensure LF
find . -name '*.sh' -exec sed -i 's/\r$//' {} + 2>/dev/null || true
chmod +x ./*.sh modules/*.sh lib/*.sh 2>/dev/null || true

PASS=0
FAIL=0
check() {
  local msg=$1; shift
  echo -n "TEST: $msg ... "
  if "$@"; then echo OK; PASS=$((PASS+1)); else echo FAIL; FAIL=$((FAIL+1)); fi
}

echo "Deep Optimizer Pro self-test"
for f in deep-optimizer-pro.sh install.sh run.sh lib/common.sh modules/*.sh; do
  check "bash -n $f" bash -n "$f"
done

check "help" bash deep-optimizer-pro.sh --help
check "version" bash deep-optimizer-pro.sh --version

echo "PASSED=$PASS FAILED=$FAIL"
[[ $FAIL -eq 0 ]]
