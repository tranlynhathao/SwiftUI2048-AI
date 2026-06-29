// Drives the AI: owns the worker, paces auto-play, guarantees a single
// in-flight search at a time, and keeps the UI responsive (even in Turbo).
import type { Game } from "./game";
import type { Dir } from "./board";

export type Speed = "slow" | "normal" | "fast" | "turbo";

export const SPEED_DELAY_MS: Record<Speed, number> = {
  slow: 500,
  normal: 200,
  fast: 80,
  turbo: 0,
};

const sleep = (ms: number) => new Promise<void>((r) => setTimeout(r, ms));
const raf = () =>
  new Promise<void>((r) => {
    if (typeof requestAnimationFrame === "function") requestAnimationFrame(() => r());
    else setTimeout(r, 0);
  });

export class AIController {
  running = false;
  thinking = false;
  depth = 1;
  speed: Speed = "normal";
  ready = false;

  private worker: Worker;
  private reqId = 0;
  private pending = new Map<number, (move: number) => void>();

  constructor(private game: Game, private onUpdate: () => void) {
    this.worker = new Worker(new URL("../wasm/ai2048.worker.ts", import.meta.url), {
      type: "module",
    });
    this.worker.onmessage = (e: MessageEvent) => {
      const m = e.data;
      if (m.type === "ready") {
        this.ready = true;
        this.onUpdate();
      } else if (m.type === "move") {
        const cb = this.pending.get(m.id);
        if (cb) {
          this.pending.delete(m.id);
          cb(m.move);
        }
      }
    };
    this.worker.postMessage({ type: "init", depth: this.depth });
  }

  setDepth(d: number): void {
    this.depth = d;
    this.worker.postMessage({ type: "setDepth", depth: d });
    this.onUpdate();
  }

  setSpeed(s: Speed): void {
    this.speed = s;
    this.onUpdate();
  }

  private requestBestMove(board: bigint): Promise<number> {
    return new Promise((resolve) => {
      const id = ++this.reqId;
      this.pending.set(id, resolve);
      this.worker.postMessage({ type: "bestMove", id, board });
    });
  }

  /** One AI move on demand (used when paused). Never overlaps a search. */
  async step(): Promise<void> {
    if (this.thinking || this.running || this.game.gameOver || !this.ready) return;
    this.thinking = true;
    this.onUpdate();
    const move = await this.requestBestMove(this.game.board);
    this.thinking = false;
    if (move < 0) {
      this.game.gameOver = true;
      this.game.endTime = Date.now();
    } else {
      this.game.move(move as Dir, true);
    }
    this.onUpdate();
  }

  start(): void {
    if (this.running || this.game.gameOver || !this.ready) return;
    this.running = true;
    this.onUpdate();
    void this.loop();
  }

  stop(): void {
    this.running = false;
    this.onUpdate();
  }

  toggle(): void {
    this.running ? this.stop() : this.start();
  }

  private async loop(): Promise<void> {
    while (this.running && !this.game.gameOver) {
      this.thinking = true;
      this.onUpdate();
      const move = await this.requestBestMove(this.game.board);
      this.thinking = false;
      if (!this.running) break; // paused while thinking
      if (move < 0) {
        this.game.gameOver = true;
        this.game.endTime = Date.now();
        break;
      }
      this.game.move(move as Dir, true);
      this.onUpdate();

      const delay = SPEED_DELAY_MS[this.speed];
      if (delay > 0) await sleep(delay);
      else await raf(); // Turbo: yield one frame so the UI can paint.
    }
    this.running = false;
    this.onUpdate();
  }
}
