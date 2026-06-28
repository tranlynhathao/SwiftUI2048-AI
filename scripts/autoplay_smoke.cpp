// End-to-end autoplay smoke test. It mimics exactly what the macOS app does:
//   encode grid -> AI_GetBestMove -> apply that direction in grid space
//   (via AI_ApplyMove) -> spawn a random tile -> repeat until no move.
// Proves the integrated encode/search/decode/spawn loop progresses and does
// not stall. Reaching a high tile (>= 512) indicates the AI plays well.
//
// Build & run:
//   clang++ -std=gnu++14 -O2 scripts/autoplay_smoke.cpp cpp/AIBridge.cpp -o /tmp/smoke && /tmp/smoke

#include "../cpp/AIBridge.h"
#include <array>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <vector>

using Grid = std::array<std::array<int, 4>, 4>;

static int nibbleIndex(int row, int col) { return (3 - row) * 4 + (3 - col); }
static int rankOf(int v) { int r = 0; while (v > 1) { v >>= 1; ++r; } return r; }

static uint64_t encode(const Grid &g) {
  uint64_t b = 0;
  for (int r = 0; r < 4; ++r)
    for (int c = 0; c < 4; ++c)
      if (g[r][c] > 0)
        b |= static_cast<uint64_t>(rankOf(g[r][c])) << (nibbleIndex(r, c) * 4);
  return b;
}
static Grid decode(uint64_t b) {
  Grid g{};
  for (int r = 0; r < 4; ++r)
    for (int c = 0; c < 4; ++c) {
      int rk = (b >> (nibbleIndex(r, c) * 4)) & 0xf;
      g[r][c] = rk == 0 ? 0 : (1 << rk);
    }
  return g;
}
static bool spawn(Grid &g) {
  std::vector<std::pair<int, int>> empty;
  for (int r = 0; r < 4; ++r)
    for (int c = 0; c < 4; ++c)
      if (g[r][c] == 0) empty.push_back({r, c});
  if (empty.empty()) return false;
  auto p = empty[rand() % empty.size()];
  g[p.first][p.second] = (rand() % 10 == 0) ? 4 : 2;
  return true;
}
static int maxTile(const Grid &g) {
  int m = 0;
  for (auto &row : g) for (int v : row) if (v > m) m = v;
  return m;
}

int main() {
  srand(12345); // deterministic
  void *ai = AI_Init(2);
  if (!ai) { printf("autoplay_smoke: FAIL (AI_Init returned null)\n"); return 1; }

  int games = 3, reached512 = 0, best = 0;
  for (int game = 0; game < games; ++game) {
    Grid g{};
    spawn(g); spawn(g);
    int moves = 0, noop = 0;
    for (;;) {
      uint64_t board = encode(g);
      int dir = AI_GetBestMove(ai, board);
      if (dir < 0) break; // game over
      uint64_t after = AI_ApplyMove(board, dir);
      if (after == board) { // should not happen: AI only returns legal moves
        if (++noop > 3) { printf("autoplay_smoke: FAIL (no-op loop)\n"); AI_Release(ai); return 1; }
        continue;
      }
      noop = 0;
      g = decode(after);
      if (!spawn(g)) break;
      ++moves;
      if (moves > 100000) break; // safety
    }
    int mt = maxTile(g);
    if (mt > best) best = mt;
    if (mt >= 512) ++reached512;
    printf("  game %d: moves=%d maxTile=%d\n", game + 1, moves, mt);
  }
  AI_Release(ai);

  if (best >= 512) {
    printf("autoplay_smoke: PASS (best maxTile=%d, %d/%d games reached >=512)\n", best, reached512, games);
    return 0;
  }
  printf("autoplay_smoke: WEAK (best maxTile=%d) — loop progressed but play is weak\n", best);
  return best >= 64 ? 0 : 1; // still pass if it clearly progressed
}
