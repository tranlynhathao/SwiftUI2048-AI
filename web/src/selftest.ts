// In-browser self-test of the WASM <-> TS boundary. Runs at startup and logs
// the result. Mirrors the native AIBridgeSelfTest: encode/decode round-trip,
// move equivalence vs the pure reference, legality, and score deltas.
import { Ai2048 } from "./wasm/ai2048";
import { encode, decode, referenceTransform, type Dir, type Grid } from "./game/board";

const BOARDS: Grid[] = [
  [[2, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]],
  [[2, 4, 8, 16], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]],
  [[2, 0, 0, 0], [4, 0, 0, 0], [8, 0, 0, 0], [16, 0, 0, 0]],
  [[2, 2, 2, 0], [0, 4, 4, 0], [8, 0, 8, 0], [0, 0, 0, 2]],
  [[2, 4, 2, 4], [4, 2, 4, 2], [2, 4, 2, 4], [4, 2, 4, 0]],
  [[2, 2, 2, 2], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]],
];
const DIRS: Dir[] = [0, 1, 2, 3];
const eq = (a: Grid, b: Grid) => JSON.stringify(a) === JSON.stringify(b);

export interface SelfTestResult {
  passed: boolean;
  summary: string;
  failures: string[];
}

export function runSelfTest(w: Ai2048): SelfTestResult {
  const failures: string[] = [];

  // Round-trip encode/decode.
  for (let i = 0; i < BOARDS.length; i++) {
    if (!eq(decode(encode(BOARDS[i])), BOARDS[i])) failures.push(`round-trip board#${i}`);
  }

  // Move equivalence + legality + score.
  for (let i = 0; i < BOARDS.length; i++) {
    for (const dir of DIRS) {
      const ref = referenceTransform(BOARDS[i], dir);
      const enc = encode(BOARDS[i]);
      const got = decode(w.applyMove(enc, dir));
      if (!eq(ref.grid, got)) failures.push(`move board#${i} dir${dir}: ref!=wasm`);
      if (ref.changed !== w.isMoveLegal(enc, dir)) failures.push(`legal board#${i} dir${dir}`);
      if (ref.score !== w.scoreDelta(enc, dir)) failures.push(`score board#${i} dir${dir}: ref=${ref.score} wasm=${w.scoreDelta(enc, dir)}`);
    }
  }

  // Explicit score expectations.
  const s2 = w.scoreDelta(encode([[2, 2, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]]), 3);
  if (s2 !== 4) failures.push(`2+2 left expected +4, got ${s2}`);
  const s4 = w.scoreDelta(encode([[4, 4, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]]), 3);
  if (s4 !== 8) failures.push(`4+4 left expected +8, got ${s4}`);
  const s8 = w.scoreDelta(encode([[2, 2, 2, 2], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]]), 1);
  if (s8 !== 8) failures.push(`[2,2,2,2] right expected +8, got ${s8}`);

  // No-op detection: a packed row moved left is a no-op.
  const noop = encode([[2, 4, 8, 16], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]]);
  if (w.isMoveLegal(noop, 3)) failures.push("expected left no-op on packed top row");

  // AI returns a legal move or -1.
  const handle = w.aiCreate(1);
  try {
    const b = encode([[2, 2, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]]);
    const mv = w.aiBestMove(handle, b);
    if (mv < -1 || mv > 3) failures.push(`AI move out of range: ${mv}`);
    if (mv >= 0 && !w.isMoveLegal(b, mv)) failures.push(`AI returned illegal move ${mv}`);
    // Game-over board: full, no merges -> AI returns -1.
    const over = encode([[2, 4, 2, 4], [4, 2, 4, 2], [2, 4, 2, 4], [4, 2, 4, 2]]);
    if (w.aiBestMove(handle, over) !== -1) failures.push("AI should return -1 on game over");
  } finally {
    w.aiDestroy(handle);
  }

  const passed = failures.length === 0;
  const total = BOARDS.length * DIRS.length;
  const summary = passed
    ? `WASM self-test: PASS (${BOARDS.length} boards × ${DIRS.length} dirs = ${total} move-checks + score/AI checks)`
    : `WASM self-test: FAIL (${failures.length} failures)`;
  return { passed, summary, failures };
}
