// Type shim for the Emscripten-generated ES module (no bundled types).
// Matches both the app build (ai2048.js) and the node test build (ai2048.node.mjs).

interface AI2048RawModule {
  _wasm_ai_create(depth: number): number;
  _wasm_ai_destroy(handle: number): void;
  _wasm_ai_best_move(handle: number, board: bigint): number;
  _wasm_apply_move(board: bigint, direction: number): bigint;
  _wasm_is_move_legal(board: bigint, direction: number): number;
  _wasm_move_score_delta(board: bigint, direction: number): number;
  _wasm_max_tile(board: bigint): number;
  _wasm_count_empty(board: bigint): number;
  _wasm_set_cell(board: bigint, row: number, col: number, rank: number): bigint;
  _wasm_get_cell_rank(board: bigint, row: number, col: number): number;
  _wasm_new_game_board(seed: number): bigint;
}

declare module "*/ai2048.js" {
  const createAI2048Module: (moduleArg?: Record<string, unknown>) => Promise<AI2048RawModule>;
  export default createAI2048Module;
}
