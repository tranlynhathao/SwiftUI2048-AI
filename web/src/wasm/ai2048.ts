// Thin, typed wrapper over the Emscripten-generated module. All 64-bit boards
// are JS BigInt (compiled with -sWASM_BIGINT). Direction codes: 0=up, 1=right,
// 2=down, 3=left. Board orientation matches the native, verified integration.
import createAI2048Module from "./generated/ai2048.js";

export class Ai2048 {
  private constructor(private readonly m: AI2048RawModule) {}

  static async load(): Promise<Ai2048> {
    const m = await createAI2048Module();
    return new Ai2048(m);
  }

  // Pure board operations.
  applyMove(board: bigint, dir: number): bigint {
    return this.m._wasm_apply_move(board, dir);
  }
  isMoveLegal(board: bigint, dir: number): boolean {
    return this.m._wasm_is_move_legal(board, dir) !== 0;
  }
  scoreDelta(board: bigint, dir: number): number {
    return this.m._wasm_move_score_delta(board, dir);
  }
  maxTile(board: bigint): number {
    return this.m._wasm_max_tile(board);
  }
  countEmpty(board: bigint): number {
    return this.m._wasm_count_empty(board);
  }
  setCell(board: bigint, row: number, col: number, rank: number): bigint {
    return this.m._wasm_set_cell(board, row, col, rank);
  }
  getCellRank(board: bigint, row: number, col: number): number {
    return this.m._wasm_get_cell_rank(board, row, col);
  }

  // AI handle lifecycle + query.
  aiCreate(depth: number): number {
    return this.m._wasm_ai_create(depth);
  }
  aiDestroy(handle: number): void {
    this.m._wasm_ai_destroy(handle);
  }
  aiBestMove(handle: number, board: bigint): number {
    return this.m._wasm_ai_best_move(handle, board);
  }
}
