//
//  WasmBridge.cpp
//  SwiftUI2048_AI
//
//  WebAssembly C ABI implementation. Reuses the existing C++ AI core
//  (search.hpp -> board/move/hash/heuristic). Compiled only by Emscripten.
//

#include "WasmBridge.h"
#include "search.hpp" // pulls in board.hpp, move.hpp, hash.hpp, heuristic.hpp

#ifdef __EMSCRIPTEN__
#include <emscripten/emscripten.h>
#else
#define EMSCRIPTEN_KEEPALIVE
#endif

namespace {

// Canonical cell <-> nibble mapping, identical to the Swift/TS side.
inline int nibbleShift(int row, int col) { return ((3 - row) * 4 + (3 - col)) * 4; }

// Standard-2048 score for one 16-bit row (direction-independent: the set of
// merges is the same sliding either way). Ranks are nibble values; a merge of
// two rank-r tiles yields a rank-(r+1) tile worth 2^(r+1) points.
inline int rowScore(unsigned row) {
  int tiles[4];
  int n = 0;
  for (int i = 0; i < 4; ++i) {
    int r = (row >> (i * 4)) & 0xf;
    if (r) tiles[n++] = r;
  }
  int score = 0;
  for (int i = 0; i < n;) {
    if (i + 1 < n && tiles[i] == tiles[i + 1]) {
      score += 1 << (tiles[i] + 1);
      i += 2;
    } else {
      ++i;
    }
  }
  return score;
}

struct WasmAI {
  Search *search;
  Move move;
  explicit WasmAI(int depth) : search(new Search(depth < 1 ? 1 : depth)) { hash.CLear(); }
  ~WasmAI() { delete search; }
};

} // namespace

extern "C" {

EMSCRIPTEN_KEEPALIVE
void *wasm_ai_create(int depth) { return new WasmAI(depth); }

EMSCRIPTEN_KEEPALIVE
void wasm_ai_destroy(void *handle) {
  if (handle) delete static_cast<WasmAI *>(handle);
}

EMSCRIPTEN_KEEPALIVE
int wasm_ai_best_move(void *handle, uint64_t board) {
  if (!handle) return -1;
  WasmAI *ai = static_cast<WasmAI *>(handle);
  Search &search = *(ai->search);
  Move &move = ai->move;
  board_t b = static_cast<board_t>(board);

  int best = -1;
  float maxScore = -1.0f;
  // Search::operator()(board, dir) applies the move itself, so pass the
  // ORIGINAL board + direction. Pre-check legality so we never return a no-op.
  for (int dir = 0; dir < 4; ++dir) {
    if (move(b, dir) != b) {
      float score = search(b, dir);
      if (score > maxScore) {
        maxScore = score;
        best = dir;
      }
    }
  }
  return best;
}

EMSCRIPTEN_KEEPALIVE
uint64_t wasm_apply_move(uint64_t board, int direction) {
  if (direction < 0 || direction > 3) return board;
  Move move;
  return static_cast<uint64_t>(move(static_cast<board_t>(board), direction));
}

EMSCRIPTEN_KEEPALIVE
int wasm_is_move_legal(uint64_t board, int direction) {
  if (direction < 0 || direction > 3) return 0;
  Move move;
  board_t b = static_cast<board_t>(board);
  return move(b, direction) != b ? 1 : 0;
}

EMSCRIPTEN_KEEPALIVE
int wasm_move_score_delta(uint64_t board, int direction) {
  if (direction < 0 || direction > 3) return 0;
  Move move;
  board_t b = static_cast<board_t>(board);
  if (move(b, direction) == b) return 0; // no-op -> no score
  // Up/down score is computed on columns via transpose; left/right on rows.
  board_t t = (direction == 0 || direction == 2) ? Transpose(b) : b;
  int score = 0;
  for (int r = 0; r < 4; ++r) {
    score += rowScore(static_cast<unsigned>((t >> (r * 16)) & 0xffff));
  }
  return score;
}

EMSCRIPTEN_KEEPALIVE
int wasm_max_tile(uint64_t board) {
  int rank = MaxRank(static_cast<board_t>(board));
  return rank == 0 ? 0 : (1 << rank);
}

EMSCRIPTEN_KEEPALIVE
int wasm_count_empty(uint64_t board) {
  return CountEmpty(static_cast<board_t>(board));
}

EMSCRIPTEN_KEEPALIVE
uint64_t wasm_set_cell(uint64_t board, int row, int col, int rank) {
  if (row < 0 || row > 3 || col < 0 || col > 3 || rank < 0 || rank > 15) return board;
  int shift = nibbleShift(row, col);
  board_t b = static_cast<board_t>(board);
  b &= ~(static_cast<board_t>(0xf) << shift);
  b |= static_cast<board_t>(rank & 0xf) << shift;
  return static_cast<uint64_t>(b);
}

EMSCRIPTEN_KEEPALIVE
int wasm_get_cell_rank(uint64_t board, int row, int col) {
  if (row < 0 || row > 3 || col < 0 || col > 3) return 0;
  return static_cast<int>((static_cast<board_t>(board) >> nibbleShift(row, col)) & 0xf);
}

EMSCRIPTEN_KEEPALIVE
uint64_t wasm_new_game_board(uint32_t seed) {
  // Simple LCG so the optional starting board is deterministic from a seed.
  uint32_t s = seed ? seed : 1u;
  auto next = [&s]() { s = s * 1664525u + 1013904223u; return s; };
  board_t b = 0;
  for (int t = 0; t < 2; ++t) {
    // pick a random empty cell
    int empties[16], n = 0;
    for (int i = 0; i < 16; ++i)
      if (((b >> (i * 4)) & 0xf) == 0) empties[n++] = i;
    if (!n) break;
    int idx = empties[next() % n];
    int rank = (next() % 10 == 0) ? 2 : 1; // 10% -> 4 (rank 2), else 2 (rank 1)
    b |= static_cast<board_t>(rank) << (idx * 4);
  }
  return static_cast<uint64_t>(b);
}

} // extern "C"
