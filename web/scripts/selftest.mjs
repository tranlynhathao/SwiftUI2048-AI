// Node CLI self-test for the WASM AI boundary. Uses the node-flavored module
// (build with: npm run build:wasm:node). Exits non-zero on any failure.
import createAI2048Module from "../src/wasm/generated/ai2048.node.mjs";

const SIZE = 4;
const shift = (row, col) => BigInt(((3 - row) * 4 + (3 - col)) * 4);
const valueToRank = (v) => (v <= 0 ? 0 : Math.round(Math.log2(v)));
const rankToValue = (r) => (r === 0 ? 0 : 1 << r);

function encode(grid) {
  let b = 0n;
  for (let r = 0; r < SIZE; r++)
    for (let c = 0; c < SIZE; c++) {
      const rank = valueToRank(grid[r][c]);
      if (rank > 0) b |= BigInt(rank) << shift(r, c);
    }
  return b;
}
function decode(b) {
  const g = [];
  for (let r = 0; r < SIZE; r++) {
    const row = [];
    for (let c = 0; c < SIZE; c++) row.push(rankToValue(Number((b >> shift(r, c)) & 0xfn)));
    g.push(row);
  }
  return g;
}
function slideMerge(line) {
  const tiles = line.filter((v) => v !== 0);
  const out = [];
  let score = 0, i = 0;
  while (i < tiles.length) {
    if (i + 1 < tiles.length && tiles[i] === tiles[i + 1]) {
      out.push(tiles[i] * 2); score += tiles[i] * 2; i += 2;
    } else { out.push(tiles[i]); i += 1; }
  }
  while (out.length < SIZE) out.push(0);
  return { line: out, score };
}
function reference(grid, dir) {
  const g = grid.map((r) => r.slice());
  let score = 0;
  const apply = (line, reverse) => {
    const input = reverse ? line.slice().reverse() : line;
    const res = slideMerge(input);
    score += res.score;
    return reverse ? res.line.reverse() : res.line;
  };
  if (dir === 3 || dir === 1) {
    const rev = dir === 1;
    for (let r = 0; r < SIZE; r++) g[r] = apply(g[r], rev);
  } else {
    const rev = dir === 2;
    for (let c = 0; c < SIZE; c++) {
      const col = [g[0][c], g[1][c], g[2][c], g[3][c]];
      const m = apply(col, rev);
      for (let r = 0; r < SIZE; r++) g[r][c] = m[r];
    }
  }
  const changed = JSON.stringify(g) !== JSON.stringify(grid);
  return { grid: g, changed, score };
}
const eq = (a, b) => JSON.stringify(a) === JSON.stringify(b);

const BOARDS = [
  [[2, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]],
  [[2, 4, 8, 16], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]],
  [[2, 0, 0, 0], [4, 0, 0, 0], [8, 0, 0, 0], [16, 0, 0, 0]],
  [[2, 2, 2, 0], [0, 4, 4, 0], [8, 0, 8, 0], [0, 0, 0, 2]],
  [[2, 4, 2, 4], [4, 2, 4, 2], [2, 4, 2, 4], [4, 2, 4, 0]],
  [[2, 2, 2, 2], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]],
];
const DIRS = [0, 1, 2, 3];

const m = await createAI2048Module();
const failures = [];

for (let i = 0; i < BOARDS.length; i++) {
  if (!eq(decode(encode(BOARDS[i])), BOARDS[i])) failures.push(`round-trip board#${i}`);
  for (const dir of DIRS) {
    const ref = reference(BOARDS[i], dir);
    const enc = encode(BOARDS[i]);
    const got = decode(m._wasm_apply_move(enc, dir));
    if (!eq(ref.grid, got)) failures.push(`move board#${i} dir${dir}`);
    if (ref.changed !== (m._wasm_is_move_legal(enc, dir) !== 0)) failures.push(`legal board#${i} dir${dir}`);
    if (ref.score !== m._wasm_move_score_delta(enc, dir)) failures.push(`score board#${i} dir${dir}`);
  }
}

// Direction mapping: a single tile in the middle slides to the expected edge.
const mid = [[0, 0, 0, 0], [0, 2, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]];
const checkDir = (dir, rc) => {
  const g = decode(m._wasm_apply_move(encode(mid), dir));
  if (g[rc[0]][rc[1]] !== 2) failures.push(`dir ${dir} did not move tile to (${rc})`);
};
checkDir(0, [0, 1]); // up -> top row
checkDir(2, [3, 1]); // down -> bottom row
checkDir(3, [1, 0]); // left -> left col
checkDir(1, [1, 3]); // right -> right col

// Explicit score checks.
if (m._wasm_move_score_delta(encode([[2, 2, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]]), 3) !== 4) failures.push("2+2 -> +4");
if (m._wasm_move_score_delta(encode([[4, 4, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]]), 3) !== 8) failures.push("4+4 -> +8");
if (m._wasm_move_score_delta(encode([[2, 2, 2, 2], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]]), 3) !== 8) failures.push("[2,2,2,2] -> +8");

// AI returns legal move or -1.
const h = m._wasm_ai_create(2);
const b = encode([[2, 2, 0, 0], [4, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]]);
const mv = m._wasm_ai_best_move(h, b);
if (mv < -1 || mv > 3) failures.push(`AI move out of range: ${mv}`);
if (mv >= 0 && m._wasm_is_move_legal(b, mv) === 0) failures.push(`AI returned illegal move ${mv}`);
const over = encode([[2, 4, 2, 4], [4, 2, 4, 2], [2, 4, 2, 4], [4, 2, 4, 2]]);
if (m._wasm_ai_best_move(h, over) !== -1) failures.push("AI should return -1 on game over");
m._wasm_ai_destroy(h);

if (failures.length === 0) {
  console.log(`selftest: PASS (${BOARDS.length} boards × ${DIRS.length} dirs + direction/score/AI checks)`);
  process.exit(0);
} else {
  console.error(`selftest: FAIL (${failures.length})`);
  for (const f of failures) console.error("  - " + f);
  process.exit(1);
}
