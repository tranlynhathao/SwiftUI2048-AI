// Web Worker that owns the AI handle and runs the (potentially heavy)
// expectimax search off the main thread. The main thread sends a board + depth
// and gets back the best move. One request is processed at a time.
import { Ai2048 } from "./ai2048";

type InMessage =
  | { type: "init"; depth: number }
  | { type: "setDepth"; depth: number }
  | { type: "bestMove"; id: number; board: bigint };

type OutMessage =
  | { type: "ready" }
  | { type: "move"; id: number; move: number };

let ai: Ai2048 | null = null;
let handle = 0;
let depth = 1;

const ctx = self as unknown as Worker;

ctx.onmessage = async (e: MessageEvent<InMessage>) => {
  const msg = e.data;

  if (msg.type === "init") {
    ai = await Ai2048.load();
    depth = msg.depth;
    handle = ai.aiCreate(depth);
    post({ type: "ready" });
    return;
  }

  if (!ai) return;

  if (msg.type === "setDepth") {
    if (msg.depth !== depth) {
      ai.aiDestroy(handle);
      depth = msg.depth;
      handle = ai.aiCreate(depth);
    }
    return;
  }

  if (msg.type === "bestMove") {
    const move = ai.aiBestMove(handle, msg.board);
    post({ type: "move", id: msg.id, move });
  }
};

function post(m: OutMessage) {
  ctx.postMessage(m);
}
