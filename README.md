# 2048 Game (SwiftUI app)

This is a simple game to demonstrate the new SwiftUI framework.

> Note that the game algorithm may have issues, and this is still WIP.

# 2048 AI

An AI made for the game 2048.
The AI can reach 16384 most of the time and sometimes even reach 32768.

The AI reached the 32768 tile in the browser version after 5 attempts and achieved the score of 630032. Below is the screenshot of that game.

> Note Demo without AI
> ![Demo](input.gif)

## Supported Platforms

- iOS 13.0+
- macOS 10.15+
- macOS 11+ (macCatalyst version)
- Web (WebAssembly) — see below

## Project Layout

```
Native/                     Native Swift app
  Shared/                   code shared by macOS + iOS
    Models/                 GameLogic, BlockMatrix, IdentifiedBlock
    Views/                  GameView, BlockGridView, BlockView
    AI/                     AIPlayer, AIBridgeSelfTest, SwiftUI2048-Bridging-Header.h
    Theme/                  Palette (shared colors)
    Support/                FunctionalUtils, SwiftUIExtensions
  macOS/                    macOS-only
    App/                    AppDelegate (AppKit), GameMainHostingView
    Resources/              Assets.xcassets, Main.storyboard, Preview Content
    Config/                 Info.plist, entitlements
  iOS/                      iOS-only
    App/                    AppDelegate
    Resources/              Assets.xcassets, LaunchScreen.storyboard, MainMenu.xib, Preview Content
    Config/                 Info.plist, entitlements
cpp/                        Shared C++ AI core + bridges (AIBridge = native, WasmBridge = web)
web/                        Vite + TypeScript WebAssembly demo
scripts/                    C++ test harnesses (orientation, autoplay)
docs/                       Reports
SwiftUI2048_AI.xcodeproj/   Xcode project (2 app targets)
```

Targets / schemes:

- `2048(macOS)` — **macOS** native app (AppKit lifecycle). Builds and runs; uses the C++ AI.
- `2048` — **iOS** native app (shares all `Native/Shared` code). See iOS note below.

Build commands:

```sh
# C++ native bridge
clang++ -std=gnu++14 -c cpp/AIBridge.cpp -o /tmp/AIBridge.o

# macOS app
xcodebuild -project SwiftUI2048_AI.xcodeproj -scheme "2048(macOS)" -destination 'platform=macOS' build

# iOS app (requires the iOS platform installed in Xcode)
xcodebuild -project SwiftUI2048_AI.xcodeproj -scheme "2048" -destination 'generic/platform=iOS' build CODE_SIGNING_ALLOWED=NO

# Web demo
cd web && npm install && npm run build:wasm && npm run build
```

> **iOS note:** the iOS target shares all `Native/Shared` Swift code and its Info.plist / entitlements / bridging-header settings point at `Native/iOS` and `Native/Shared/AI`. AI autoplay is currently guarded with `#if os(macOS)` so the iOS target stays compile-safe; the C++ AI core already compiles for the iOS SDK. To enable AI on iOS: add `Native/Shared/AI/AIPlayer.swift`, `Native/Shared/AI/AIBridgeSelfTest.swift`, and `cpp/AIBridge.cpp` to the `2048` target, set its `SWIFT_OBJC_BRIDGING_HEADER` to `Native/Shared/AI/SwiftUI2048-Bridging-Header.h`, and remove the `#if os(macOS)` guards in `GameLogic.swift` / `GameView.swift`.

## Running in Xcode

The project has two app targets/schemes with distinct, non-overlapping roles
(target `2048` is iOS/iPadOS only — Mac Catalyst is disabled):

**Native macOS**
- Scheme: `2048(macOS)`
- Destination: **My Mac**

**Native iOS / iPadOS**
- Scheme: `2048`
- Destination: an **iPhone/iPad Simulator** or a **physical iOS device**
- A physical device requires setting an Apple Development Team under
  *Signing & Capabilities* (this is normal for on-device runs and is not committed
  to the repo — `DEVELOPMENT_TEAM` is intentionally left empty).

**Do not** select `2048 > My Mac (Mac Catalyst)` — Catalyst is disabled, so the
native `2048(macOS)` target is the only macOS app. If you previously saw both iOS
and macOS signing sections on `2048`, that was Mac Catalyst; it has been turned off.

## Web Demo (WebAssembly)

A browser version of the demo lives in [`web/`](web/). The 2048 board operations and the AI move selection run in **WebAssembly**, compiled by Emscripten from the same C++ Expectimax engine in [`cpp/`](cpp/) — it is not a JS reimplementation. TypeScript (Vite) handles the UI, random tile spawning, and persistence.

- WASM bridge: `cpp/WasmBridge.cpp` (compiled only by Emscripten; the native Xcode targets are untouched).
- Build/run: see [`web/README.md`](web/README.md).

```sh
cd web
npm install
npm run build:wasm   # C++ -> WASM (requires emcc)
npm run test         # WASM boundary self-tests
npm run dev          # local dev at /SwiftUI2048-AI/
```
