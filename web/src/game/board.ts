// Pure TS board helpers. Board is a 64-bit bitboard (BigInt), one 4-bit nibble
// per cell, value = rank (0 empty, n -> 2^n). Canonical cell (row, col) maps to
// nibble index (3 - row) * 4 + (3 - col) — identical to the native/WASM side.

export const SIZE = 4;
export type Grid = number[][]; // values (0 = empty), grid[row][col]
export type Dir = 0 | 1 | 2 | 3; // 0=up, 1=right, 2=down, 3=left

export function nibbleShift(row: number, col: number): bigint {
  return BigInt(((3 - row) * 4 + (3 - col)) * 4);
}

export function rankToValue(rank: number): number {
  return rank === 0 ? 0 : 1 << rank;
}

export function valueToRank(value: number): number {
  if (value <= 0) return 0;
  return Math.round(Math.log2(value));
}

export function decode(board: bigint): Grid {
  const g: Grid = [];
  for (let row = 0; row < SIZE; row++) {
    const r: number[] = [];
    for (let col = 0; col < SIZE; col++) {
      const rank = Number((board >> nibbleShift(row, col)) & 0xfn);
      r.push(rankToValue(rank));
    }
    g.push(r);
  }
  return g;
}

export function encode(grid: Grid): bigint {
  let board = 0n;
  for (let row = 0; row < SIZE; row++) {
    for (let col = 0; col < SIZE; col++) {
      const rank = valueToRank(grid[row][col]);
      if (rank > 0) board |= BigInt(rank) << nibbleShift(row, col);
    }
  }
  return board;
}

export function maxTileOf(grid: Grid): number {
  let m = 0;
  for (const row of grid) for (const v of row) if (v > m) m = v;
  return m;
}

export function emptyCells(grid: Grid): Array<[number, number]> {
  const cells: Array<[number, number]> = [];
  for (let row = 0; row < SIZE; row++)
    for (let col = 0; col < SIZE; col++)
      if (grid[row][col] === 0) cells.push([row, col]);
  return cells;
}

// ---- Pure reference standard-2048 (used only by self-tests) ----

function slideMerge(line: number[]): { line: number[]; score: number } {
  const tiles = line.filter((v) => v !== 0);
  const out: number[] = [];
  let score = 0;
  let i = 0;
  while (i < tiles.length) {
    if (i + 1 < tiles.length && tiles[i] === tiles[i + 1]) {
      const merged = tiles[i] * 2;
      out.push(merged);
      score += merged;
      i += 2;
    } else {
      out.push(tiles[i]);
      i += 1;
    }
  }
  while (out.length < SIZE) out.push(0);
  return { line: out, score };
}

export function referenceTransform(grid: Grid, dir: Dir): { grid: Grid; changed: boolean; score: number } {
  const g: Grid = grid.map((r) => r.slice());
  let score = 0;
  const apply = (line: number[], reverse: boolean): number[] => {
    const input = reverse ? line.slice().reverse() : line;
    const res = slideMerge(input);
    score += res.score;
    return reverse ? res.line.reverse() : res.line;
  };

  if (dir === 3 || dir === 1) {
    const reverse = dir === 1; // right
    for (let r = 0; r < SIZE; r++) g[r] = apply(g[r], reverse);
  } else {
    const reverse = dir === 2; // down
    for (let c = 0; c < SIZE; c++) {
      const col = [g[0][c], g[1][c], g[2][c], g[3][c]];
      const merged = apply(col, reverse);
      for (let r = 0; r < SIZE; r++) g[r][c] = merged[r];
    }
  }

  let changed = false;
  for (let r = 0; r < SIZE && !changed; r++)
    for (let c = 0; c < SIZE; c++)
      if (g[r][c] !== grid[r][c]) { changed = true; break; }

  return { grid: g, changed, score };
}
