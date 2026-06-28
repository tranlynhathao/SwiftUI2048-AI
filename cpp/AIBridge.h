//
//  AIBridge.h
//  SwiftUI2048_AI
//
//  Bridge header for C++ AI to Swift
//  This header uses only C types to be compatible with Swift bridging
//

#ifndef AIBridge_h
#define AIBridge_h

#ifdef __cplusplus
extern "C" {
#endif

// Direction mapping: 0=up, 1=right, 2=down, 3=left
// Using unsigned long long (UInt64 in Swift) to represent board state
// Each 4 bits represents a tile: 0=empty, 1=2, 2=4, 3=8, etc.

// Initialize AI with search depth
// Returns: pointer to AI instance (void* in C, UnsafeMutableRawPointer in Swift)
void *AI_Init(int depth);

// Cleanup AI instance
void AI_Release(void *ai);

// Get best move for current board state
// Parameters:
//   ai: AI instance pointer
//   board: board state as 64-bit unsigned integer
// Returns: 0=up, 1=right, 2=down, 3=left, -1 if no valid move
int AI_GetBestMove(void *ai, unsigned long long board);

// Apply a slide+merge in the given direction WITHOUT spawning a tile.
// Pure function of (board, direction); used for orientation verification.
// direction: 0=up, 1=right, 2=down, 3=left. Returns the resulting board.
unsigned long long AI_ApplyMove(unsigned long long board, int direction);

// Returns 1 if the given direction changes the board, 0 otherwise.
int AI_IsMoveLegal(unsigned long long board, int direction);

// Convert board to string for debugging (optional)
const char *AI_BoardToString(unsigned long long board);

#ifdef __cplusplus
}
#endif

#endif /* AIBridge_h */
