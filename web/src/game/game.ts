// Game state. Board operations (move, score delta, legality, max tile) come
// from WASM; TypeScript owns UI state, random tile spawning, and persistence.
import { Ai2048 } from "../wasm/ai2048";
import { decode, emptyCells, type Dir, type Grid, nibbleShift } from "./board";

const BEST_KEY = "swiftui2048ai.best";
const ALL_DIRS: Dir[] = [0, 1, 2, 3];

export class Game {
  board = 0n;
  score = 0;
  best = 0;
  moves = 0;
  maxTile = 0;
  won = false;
  gameOver = false;
  lastAIDir: Dir | null = null;
  startTime = Date.now();
  endTime: number | null = null;

  constructor(private readonly wasm: Ai2048) {
    this.best = Number(localStorage.getItem(BEST_KEY) ?? "0") || 0;
    this.newGame();
  }

  get grid(): Grid {
    return decode(this.board);
  }

  get elapsedSeconds(): number {
    return ((this.endTime ?? Date.now()) - this.startTime) / 1000;
  }

  get movesPerSecond(): number {
    const t = this.elapsedSeconds;
    return t > 0 ? this.moves / t : 0;
  }

  newGame(): void {
    this.board = 0n;
    this.score = 0;
    this.moves = 0;
    this.maxTile = 0;
    this.won = false;
    this.gameOver = false;
    this.lastAIDir = null;
    this.startTime = Date.now();
    this.endTime = null;
    this.spawnTile();
    this.spawnTile();
    this.maxTile = this.wasm.maxTile(this.board);
  }

  resetBest(): void {
    this.best = 0;
    localStorage.setItem(BEST_KEY, "0");
  }

  isMoveLegal(dir: Dir): boolean {
    return this.wasm.isMoveLegal(this.board, dir);
  }

  /** Apply a move. Returns true if the board changed (and a tile was spawned). */
  move(dir: Dir, fromAI = false): boolean {
    if (this.gameOver) return false;
    if (!this.wasm.isMoveLegal(this.board, dir)) {
      if (fromAI) this.lastAIDir = dir;
      return false; // no-op: no score, no move count, no spawn
    }

    const gained = this.wasm.scoreDelta(this.board, dir);
    this.board = this.wasm.applyMove(this.board, dir);
    this.score += gained;
    this.moves += 1;
    if (fromAI) this.lastAIDir = dir;

    this.spawnTile();
    this.maxTile = this.wasm.maxTile(this.board);
    if (this.maxTile >= 2048) this.won = true;
    if (this.score > this.best) {
      this.best = this.score;
      localStorage.setItem(BEST_KEY, String(this.best));
    }

    if (!this.anyMovePossible()) {
      this.gameOver = true;
      this.endTime = Date.now();
    }
    return true;
  }

  private anyMovePossible(): boolean {
    return ALL_DIRS.some((d) => this.wasm.isMoveLegal(this.board, d));
  }

  /** Spawn a random tile in an empty cell: 90% -> 2, 10% -> 4. */
  private spawnTile(): void {
    const cells = emptyCells(decode(this.board));
    if (cells.length === 0) return;
    const [row, col] = cells[Math.floor(Math.random() * cells.length)];
    const rank = Math.random() < 0.1 ? 2 : 1; // rank 2 = value 4, rank 1 = value 2
    this.board |= BigInt(rank) << nibbleShift(row, col);
  }
}
