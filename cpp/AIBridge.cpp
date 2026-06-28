//
//  AIBridge.cpp
//  SwiftUI2048_AI
//
//  C++ implementation of AI bridge
//

#include "AIBridge.h"
#include "search.hpp" // pulls in board.hpp, move.hpp, hash.hpp, heuristic.hpp
#include <cstdio>

extern "C" {

struct AIInstance {
  Search *search;
  Move move; // built once per instance (the 64K move tables are expensive)

  AIInstance(int depth) : search(new Search(depth < 1 ? 1 : depth)) {
    hash.CLear(); // Clear hash table on initialization
  }
  ~AIInstance() { delete search; }
};

void *AI_Init(int depth) { return new AIInstance(depth); }

void AI_Release(void *ai) {
  if (ai) { delete static_cast<AIInstance *>(ai); }
}

int AI_GetBestMove(void *ai, unsigned long long board) {
  if (!ai) { return -1; }

  AIInstance *instance = static_cast<AIInstance *>(ai);
  Search &search = *(instance->search);
  Move &move = instance->move;

  int bestMove = -1;
  float maxScore = -1.0f;

  // Convert unsigned long long to board_t
  board_t boardState = static_cast<board_t>(board);

  // Try all 4 directions: 0=up, 1=right, 2=down, 3=left.
  // Search::operator()(board, dir) applies the move itself, so we must pass the
  // ORIGINAL board + direction (not a pre-moved board). We still pre-check
  // legality so we never return a direction that doesn't change the board.
  for (int dir = 0; dir < 4; ++dir) {
    board_t moved = move(boardState, dir);
    if (moved != boardState) {
      float score = search(boardState, dir);
      if (score > maxScore) {
        maxScore = score;
        bestMove = dir;
      }
    }
  }

  return bestMove;
}

unsigned long long AI_ApplyMove(unsigned long long board, int direction) {
  if (direction < 0 || direction > 3) { return board; }
  Move move;
  return static_cast<unsigned long long>(move(static_cast<board_t>(board), direction));
}

int AI_IsMoveLegal(unsigned long long board, int direction) {
  if (direction < 0 || direction > 3) { return 0; }
  Move move;
  board_t b = static_cast<board_t>(board);
  return move(b, direction) != b ? 1 : 0;
}

const char *AI_BoardToString(unsigned long long board) {
  // This is a simple implementation for debugging
  // In production, you might want to use a static buffer or return Swift string
  static char buffer[256];
  // Simple representation - could be enhanced
  snprintf(buffer, sizeof(buffer), "0x%016llx", board);
  return buffer;
}

} // extern "C"
