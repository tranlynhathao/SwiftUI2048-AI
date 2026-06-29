//
//  WasmBridge.h
//  SwiftUI2048_AI
//
//  C ABI for the WebAssembly build. This is compiled ONLY by Emscripten for
//  the web demo (web/scripts/build-wasm.sh). It is never added to the Xcode
//  targets and never linked with AIBridge.cpp, so the global state in the
//  shared C++ core (search.hpp's `Hash hash;`) lives in exactly one TU here.
//
//  It reuses the existing, verified C++ AI core unchanged. Direction codes and
//  board orientation are identical to the native integration:
//    0 = up, 1 = right, 2 = down, 3 = left
//    board = 64-bit, one 4-bit nibble per cell, value = rank (0 empty, n -> 2^n)
//    canonical cell (row, col) -> nibble index (3 - row) * 4 + (3 - col)
//

#ifndef WasmBridge_h
#define WasmBridge_h

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// AI instance lifecycle.
void *wasm_ai_create(int depth);
void wasm_ai_destroy(void *handle);

// Best move 0..3 for the given board, or -1 if no move changes the board.
int wasm_ai_best_move(void *handle, uint64_t board);

// Pure board ops (no spawning).
uint64_t wasm_apply_move(uint64_t board, int direction);
int wasm_is_move_legal(uint64_t board, int direction);
int wasm_move_score_delta(uint64_t board, int direction);
int wasm_max_tile(uint64_t board);
int wasm_count_empty(uint64_t board);

// Cell helpers using the canonical (3-row)*4+(3-col) mapping. rank 0 = empty.
uint64_t wasm_set_cell(uint64_t board, int row, int col, int rank);
int wasm_get_cell_rank(uint64_t board, int row, int col);

// Optional: build a starting board with two random tiles from a seed.
uint64_t wasm_new_game_board(uint32_t seed);

#ifdef __cplusplus
}
#endif

#endif /* WasmBridge_h */
