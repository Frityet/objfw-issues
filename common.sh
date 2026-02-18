#!/usr/bin/env bash
set -euo pipefail

OBJFW_PREFIX="${OBJFW_PREFIX:-/workspaces/ObjFW/install}"
export PATH="$OBJFW_PREFIX/bin:$PATH"
export LD_LIBRARY_PATH="$OBJFW_PREFIX/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

REPRO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$REPRO_ROOT/.build"
OBJ_DIR="$BUILD_DIR/obj"
LOG_DIR="$REPRO_ROOT/.logs"
mkdir -p "$BUILD_DIR" "$OBJ_DIR" "$LOG_DIR"

compile_objfw() {
  local src="$1"
  local out="$2"
  objfw-compile -g -O0 --builddir "$OBJ_DIR" -o "$out" "$src"
}

print_header() {
  local msg="$1"
  printf '\n===== %s =====\n' "$msg"
}
