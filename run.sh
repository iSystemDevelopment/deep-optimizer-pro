#!/bin/bash
# One-shot runner for Deep Optimizer Pro (clone or curl | bash)
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/iSystemDevelopment/deep-optimizer-pro/main/run.sh | sudo bash
#   curl -fsSL .../run.sh | sudo bash -s -- --vps --dry-run
#   sudo ./run.sh --vps

set -euo pipefail

REPO_URL="${DOP_REPO_URL:-https://github.com/iSystemDevelopment/deep-optimizer-pro.git}"
BRANCH="${DOP_BRANCH:-main}"
WORKDIR="${DOP_WORKDIR:-/opt/deep-optimizer-pro-src}"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  echo -e "${RED}Run as root: sudo $0 $*${NC}" >&2
  exit 1
fi

ARGS=("$@")
# Default action for bare curl|bash with no args
if [[ ${#ARGS[@]} -eq 0 ]]; then
  ARGS=(--vps)
fi

need_cmd() { command -v "$1" &>/dev/null || { echo "Missing: $1"; exit 1; }; }

# Prefer already-installed binary
if command -v deep-optimizer &>/dev/null && [[ -x /usr/local/bin/deep-optimizer || -x "$(command -v deep-optimizer)" ]]; then
  echo -e "${GREEN}Using installed deep-optimizer${NC}"
  exec deep-optimizer "${ARGS[@]}"
fi

# Prefer local checkout (script next to this file)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || true)"
if [[ -n "${SCRIPT_DIR:-}" && -f "$SCRIPT_DIR/deep-optimizer-pro.sh" ]]; then
  chmod +x "$SCRIPT_DIR/deep-optimizer-pro.sh" "$SCRIPT_DIR"/modules/*.sh "$SCRIPT_DIR"/lib/*.sh 2>/dev/null || true
  # Normalize CRLF if any (rare on Linux)
  if command -v sed &>/dev/null; then
    sed -i 's/\r$//' "$SCRIPT_DIR/deep-optimizer-pro.sh" 2>/dev/null || true
  fi
  echo -e "${GREEN}Running from local tree: $SCRIPT_DIR${NC}"
  exec bash "$SCRIPT_DIR/deep-optimizer-pro.sh" "${ARGS[@]}"
fi

need_cmd git
need_cmd bash

echo -e "${YELLOW}Cloning $REPO_URL ($BRANCH) → $WORKDIR${NC}"
rm -rf "$WORKDIR"
git clone --depth 1 --branch "$BRANCH" "$REPO_URL" "$WORKDIR"
chmod +x "$WORKDIR/deep-optimizer-pro.sh" "$WORKDIR"/modules/*.sh "$WORKDIR"/lib/*.sh
# Ensure LF
find "$WORKDIR" -name '*.sh' -exec sed -i 's/\r$//' {} +

echo -e "${GREEN}Starting Deep Optimizer Pro…${NC}"
exec bash "$WORKDIR/deep-optimizer-pro.sh" "${ARGS[@]}"
