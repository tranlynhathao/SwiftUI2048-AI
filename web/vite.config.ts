import { defineConfig } from "vite";

// GitHub Pages project site is served from /SwiftUI2048-AI/.
// Override with BASE_PATH=/ for local/other hosting if needed.
const base = process.env.BASE_PATH ?? "/SwiftUI2048-AI/";

export default defineConfig({
  base,
  build: {
    target: "es2020",
    outDir: "dist",
    assetsInlineLimit: 0, // keep the .wasm as a separate fetchable asset
  },
  worker: {
    format: "es",
  },
  server: {
    port: 5173,
  },
});
