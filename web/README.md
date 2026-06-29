# 2048 AI — Web (WebAssembly) Demo

A browser version of the 2048 AI demo. The board operations and the AI move
selection run in **WebAssembly**, compiled from the same C++ Expectimax engine
used by the native macOS app (`cpp/`). TypeScript handles only the UI, random
tile spawning, and persistence.

Live URL (after GitHub Pages is enabled): **https://tranlynhathao.github.io/SwiftUI2048-AI/**

## How it works

- `cpp/WasmBridge.cpp` exposes a small C ABI over the existing AI core
  (`search.hpp` → `board/move/hash/heuristic`). It is compiled **only** by
  Emscripten and is never linked into the Xcode targets.
- `web/scripts/build-wasm.sh` runs `emcc` to produce
  `web/src/wasm/generated/ai2048.js` + `ai2048.wasm` (ES module, BigInt ABI).
- `web/src/wasm/ai2048.ts` is a typed wrapper. A Web Worker
  (`ai2048.worker.ts`) owns the AI handle and runs the search off the main
  thread so the UI stays smooth (even in Turbo).
- `web/src/game/` holds the TS game state. Moves/score/legality/max-tile come
  from WASM; spawning a random tile (90% → 2, 10% → 4) is done in TS.

64-bit boards are JS `BigInt` (built with `-sWASM_BIGINT`). Direction codes and
board orientation are identical to the verified native integration:
`0 = up, 1 = right, 2 = down, 3 = left`, cell `(row, col)` → nibble
`(3 - row) * 4 + (3 - col)`.

## Prerequisites

- Node 18+ and npm
- [Emscripten](https://emscripten.org/) (`emcc` on `PATH`) for the WASM build:
  ```sh
  git clone https://github.com/emscripten-core/emsdk.git
  cd emsdk && ./emsdk install latest && ./emsdk activate latest
  source ./emsdk_env.sh
  # or on macOS: brew install emscripten
  ```

## Commands

```sh
cd web
npm install
npm run build:wasm    # compile C++ -> WASM (app module: web,worker)
npm run test          # build node WASM module + run boundary self-tests
npm run dev           # local dev server (http://localhost:5173/SwiftUI2048-AI/)
npm run build         # type-check + production build into web/dist
npm run preview       # serve the production build
```

`npm run dev` and `npm run build` require the WASM module to exist, so run
`npm run build:wasm` first (CI does this automatically).

## Base path

The Vite `base` defaults to `/SwiftUI2048-AI/` for GitHub Pages project hosting.
For other hosting (or root), build with `BASE_PATH=/ npm run build`.

## Deployment

Pushing to `main` triggers `.github/workflows/deploy-web.yml`, which installs
Emscripten, builds the WASM, runs self-tests, builds the site, and deploys
`web/dist` to GitHub Pages. Enable it once via
**Settings → Pages → Source = GitHub Actions**.
