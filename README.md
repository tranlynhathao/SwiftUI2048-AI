# 2048 Game (SwiftUI app)

This is a simple game to demonstrate the new SwiftUI framework.

> Note that the game algorithm may have issues, and this is still WIP.

# 2048 AI

 An AI made for the game 2048.
 The AI can reach 16384 most of the time and sometimes even reach 32768.

 The AI reached the 32768 tile in the browser version after 5 attempts and achieved the score of 630032. Below is the screenshot of that game.

> Note Demo without AI
![Demo](input.gif)

## Supported Platforms

* iOS 13.0+
* macOS 10.15+
* macOS 11+ (macCatalyst version)
* Web (WebAssembly) — see below

## Web Demo (WebAssembly)

A browser version of the demo lives in [`web/`](web/). The 2048 board operations
and the AI move selection run in **WebAssembly**, compiled by Emscripten from the
same C++ Expectimax engine in [`cpp/`](cpp/) — it is not a JS reimplementation.
TypeScript (Vite) handles the UI, random tile spawning, and persistence.

* Live URL (after enabling GitHub Pages): **https://tranlynhathao.github.io/SwiftUI2048-AI/**
* WASM bridge: `cpp/WasmBridge.cpp` (compiled only by Emscripten; the native
  Xcode targets are untouched).
* Build/run: see [`web/README.md`](web/README.md).
* Deployment: `.github/workflows/deploy-web.yml` builds the WASM, runs
  self-tests, and deploys `web/dist` to GitHub Pages. Enable once via
  **Settings → Pages → Source = GitHub Actions**.

```sh
cd web
npm install
npm run build:wasm   # C++ -> WASM (requires emcc)
npm run test         # WASM boundary self-tests
npm run dev          # local dev at /SwiftUI2048-AI/
```
