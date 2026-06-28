// Standalone orientation / direction equivalence test for the C++ AI bridge.
//
// It mirrors the Swift encoding contract (AIBoard in AIPlayer.swift):
//   nibble index for cell (row, col) = (3 - row) * 4 + (3 - col)
//   nibble value = rank (0 = empty, 1 = 2, 2 = 4, ...)
//   direction codes: 0 = up, 1 = right, 2 = down, 3 = left
// and compares decode(AI_ApplyMove(encode(grid), dir)) against a pure
// standard-2048 reference slide/merge for several representative boards.
//
// Build & run:
//   clang++ -std=gnu++14 scripts/orientation_test.cpp cpp/AIBridge.cpp -o /tmp/otest && /tmp/otest
//
// Exit code 0 = all checks pass; non-zero = a mismatch was found.

#include "../cpp/AIBridge.h"
#include <array>
#include <cstdint>
#include <cstdio>
#include <vector>

using Grid = std::array<std::array<int, 4>, 4>;

static int nibbleIndex(int row, int col) { return (3 - row) * 4 + (3 - col); }

static int rankOf(int v) { // v is a positive power of two
  int r = 0;
  while (v > 1) { v >>= 1; ++r; }
  return r;
}

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

// Reference standard-2048 slide/merge (toward index 0), no spawning.
static std::array<int, 4> slideMerge(std::array<int, 4> line) {
  std::array<int, 4> out{0, 0, 0, 0};
  int tiles[4];
  int n = 0;
  for (int i = 0; i < 4; ++i)
    if (line[i]) tiles[n++] = line[i];
  int o = 0;
  for (int i = 0; i < n;) {
    if (i + 1 < n && tiles[i] == tiles[i + 1]) {
      out[o++] = tiles[i] * 2;
      i += 2;
    } else {
      out[o++] = tiles[i];
      i += 1;
    }
  }
  return out;
}

static Grid reference(const Grid &in, int dir) {
  Grid g = in;
  if (dir == 3) { // left
    for (int r = 0; r < 4; ++r) g[r] = slideMerge(g[r]);
  } else if (dir == 1) { // right
    for (int r = 0; r < 4; ++r) {
      std::array<int, 4> rev{g[r][3], g[r][2], g[r][1], g[r][0]};
      auto m = slideMerge(rev);
      g[r] = {m[3], m[2], m[1], m[0]};
    }
  } else if (dir == 0) { // up
    for (int c = 0; c < 4; ++c) {
      std::array<int, 4> col{g[0][c], g[1][c], g[2][c], g[3][c]};
      auto m = slideMerge(col);
      for (int r = 0; r < 4; ++r) g[r][c] = m[r];
    }
  } else if (dir == 2) { // down
    for (int c = 0; c < 4; ++c) {
      std::array<int, 4> col{g[3][c], g[2][c], g[1][c], g[0][c]};
      auto m = slideMerge(col);
      for (int r = 0; r < 4; ++r) g[3 - r][c] = m[r];
    }
  }
  return g;
}

static void printGrid(const Grid &g) {
  for (int r = 0; r < 4; ++r) {
    for (int c = 0; c < 4; ++c) printf("%6d", g[r][c]);
    printf("\n");
  }
}

int main() {
  std::vector<Grid> boards = {
      {{{2, 0, 0, 0}, {0, 0, 0, 0}, {0, 0, 0, 0}, {0, 0, 0, 0}}},
      {{{2, 4, 8, 16}, {0, 0, 0, 0}, {0, 0, 0, 0}, {0, 0, 0, 0}}},
      {{{2, 0, 0, 0}, {4, 0, 0, 0}, {8, 0, 0, 0}, {16, 0, 0, 0}}},
      {{{2, 2, 2, 0}, {0, 4, 4, 0}, {8, 0, 8, 0}, {0, 0, 0, 2}}},
      {{{2, 4, 2, 4}, {4, 2, 4, 2}, {2, 4, 2, 4}, {4, 2, 4, 0}}},
  };

  const char *names[4] = {"up", "right", "down", "left"};
  int failures = 0;
  int checks = 0;

  for (size_t i = 0; i < boards.size(); ++i) {
    // round-trip
    if (decode(encode(boards[i])) != boards[i]) {
      printf("ROUND-TRIP FAIL board #%zu\n", i);
      ++failures;
    }
    for (int dir = 0; dir < 4; ++dir) {
      ++checks;
      Grid want = reference(boards[i], dir);
      Grid got = decode(AI_ApplyMove(encode(boards[i]), dir));
      bool legalWant = (want != boards[i]);
      bool legalGot = AI_IsMoveLegal(encode(boards[i]), dir) == 1;
      if (want != got || legalWant != legalGot) {
        ++failures;
        printf("MOVE FAIL board #%zu dir=%s\n  want:\n", i, names[dir]);
        printGrid(want);
        printf("  got:\n");
        printGrid(got);
        printf("  legal want=%d got=%d\n", legalWant, legalGot);
      }
    }
  }

  if (failures == 0) {
    printf("orientation_test: PASS (%zu boards, %d direction-checks)\n", boards.size(), checks);
    return 0;
  }
  printf("orientation_test: FAIL (%d failures)\n", failures);
  return 1;
}
