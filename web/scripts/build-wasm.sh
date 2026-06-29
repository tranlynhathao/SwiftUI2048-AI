#!/usr/bin/env bash
#
# Build the C++ AI core to WebAssembly using Emscripten.
#
# Usage:
#   build-wasm.sh                 # app build  -> src/wasm/generated/ai2048.js     (env: web,worker)
#   build-wasm.sh node            # test build -> src/wasm/generated/ai2048.node.mjs (env: node)
#
# Requires emcc on PATH. Install via:
#   git clone https://github.com/emscripten-core/emsdk.git
#   cd emsdk && ./emsdk install latest && ./emsdk activate latest
#   source ./emsdk_env.sh
# (or: brew install emscripten)
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WEB_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ROOT_DIR="$(cd "$WEB_DIR/.." && pwd)"
CPP_DIR="$ROOT_DIR/cpp"
OUT_DIR="$WEB_DIR/src/wasm/generated"

MODE="${1:-app}"
if [ "$MODE" = "node" ]; then
  EMENV="node"
  OUT_FILE="$OUT_DIR/ai2048.node.mjs"
else
  EMENV="web,worker"
  OUT_FILE="$OUT_DIR/ai2048.js"
fi

if ! command -v emcc >/dev/null 2>&1; then
  echo "ERROR: emcc (Emscripten) not found on PATH." >&2
  echo "" >&2
  echo "Install Emscripten, then re-run:" >&2
  echo "  git clone https://github.com/emscripten-core/emsdk.git" >&2
  echo "  cd emsdk && ./emsdk install latest && ./emsdk activate latest" >&2
  echo "  source ./emsdk_env.sh" >&2
  echo "Or on macOS: brew install emscripten" >&2
  exit 1
fi

mkdir -p "$OUT_DIR"

EXPORTED_FUNCTIONS='["_wasm_ai_create","_wasm_ai_destroy","_wasm_ai_best_move","_wasm_apply_move","_wasm_is_move_legal","_wasm_move_score_delta","_wasm_max_tile","_wasm_count_empty","_wasm_set_cell","_wasm_get_cell_rank","_wasm_new_game_board","_malloc","_free"]'
EXPORTED_RUNTIME='["ccall","cwrap"]'

echo "emcc: $(emcc --version | head -1)"
echo "Building $CPP_DIR/WasmBridge.cpp -> $OUT_FILE (ENVIRONMENT=$EMENV)"

emcc "$CPP_DIR/WasmBridge.cpp" \
  -O3 \
  -std=gnu++14 \
  -I"$CPP_DIR" \
  -sMODULARIZE=1 \
  -sEXPORT_ES6=1 \
  -sWASM_BIGINT=1 \
  -sALLOW_MEMORY_GROWTH=1 \
  -sSTACK_SIZE=16777216 \
  -sINITIAL_MEMORY=134217728 \
  -sENVIRONMENT="$EMENV" \
  -sEXPORT_NAME=createAI2048Module \
  -sEXPORTED_FUNCTIONS="$EXPORTED_FUNCTIONS" \
  -sEXPORTED_RUNTIME_METHODS="$EXPORTED_RUNTIME" \
  -o "$OUT_FILE"

echo "WASM build complete:"
ls -la "$OUT_DIR"
