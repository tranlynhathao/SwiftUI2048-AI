import "./styles.css";
import { Ai2048 } from "./wasm/ai2048";
import { Game } from "./game/game";
import { AIController, type Speed } from "./game/ai-controller";
import { decode, type Dir } from "./game/board";
import { runSelfTest } from "./selftest";

const $ = <T extends HTMLElement = HTMLElement>(id: string): T =>
  document.getElementById(id) as T;

const DIR_SYMBOL = ["↑", "→", "↓", "←"];
const cap = (s: string) => s.charAt(0).toUpperCase() + s.slice(1);

function fmtTime(sec: number): string {
  const s = Math.floor(sec);
  return `${String(Math.floor(s / 60)).padStart(2, "0")}:${String(s % 60).padStart(2, "0")}`;
}

async function main(): Promise<void> {
  const wasm = await Ai2048.load();

  // Boundary self-test (non-fatal; logged to console).
  try {
    const r = runSelfTest(wasm);
    console.log(r.summary);
    if (!r.passed) console.warn("Self-test failures:", r.failures);
  } catch (e) {
    console.error("Self-test error:", e);
  }

  const game = new Game(wasm);
  const ai = new AIController(game, render);

  // Build the 16 board cells once.
  const boardEl = $("board");
  const cells: HTMLDivElement[] = [];
  for (let i = 0; i < 16; i++) {
    const d = document.createElement("div");
    d.className = "cell";
    boardEl.appendChild(d);
    cells.push(d);
  }
  let prev: number[][] = [[0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]];

  function renderBoard(): void {
    const g = decode(game.board);
    for (let r = 0; r < 4; r++) {
      for (let c = 0; c < 4; c++) {
        const v = g[r][c];
        const el = cells[r * 4 + c];
        el.textContent = v ? String(v) : "";
        let cls = "cell";
        if (v) {
          cls += ` t${v}`;
          if (v !== prev[r][c]) cls += " filled"; // retrigger pop on change
        }
        el.className = cls;
      }
    }
    prev = g;
  }

  function renderOverlayStats(): void {
    const stats: Array<[string, string]> = [
      ["Score", String(game.score)],
      ["Best", String(game.best)],
      ["Max Tile", String(game.maxTile)],
      ["Moves", String(game.moves)],
      ["Time", fmtTime(game.elapsedSeconds)],
      ["Moves/s", game.movesPerSecond.toFixed(1)],
    ];
    $("overlay-stats").innerHTML = stats
      .map(([k, v]) => `<dt>${k}</dt><dd>${v}</dd>`)
      .join("");
  }

  function setSegActive(groupId: string, attr: string, value: string): void {
    const group = $(groupId);
    group.querySelectorAll("button").forEach((b) => {
      b.classList.toggle("active", (b as HTMLElement).dataset[attr] === value);
    });
  }

  function render(): void {
    renderBoard();
    $("score").textContent = String(game.score);
    $("best").textContent = String(game.best);
    $("moves").textContent = String(game.moves);
    $("maxtile").textContent = game.maxTile ? String(game.maxTile) : "—";
    $("maxtile-card").classList.toggle("win", game.maxTile >= 2048);
    $("win-badge").classList.toggle("hidden", !game.won);

    const dot = $("status-dot");
    dot.className = "dot";
    let status: string;
    if (game.gameOver) {
      dot.classList.add("over");
      status = "Game Over";
    } else if (ai.thinking) {
      dot.classList.add("thinking");
      status = `AI: Thinking… · Depth ${ai.depth}`;
    } else if (ai.running) {
      dot.classList.add("running");
      status = `AI: Running · ${cap(ai.speed)} · Depth ${ai.depth}`;
    } else if (!ai.ready) {
      status = "Loading AI…";
    } else {
      status = "AI: Manual";
    }
    if (game.lastAIDir != null) status += ` · last ${DIR_SYMBOL[game.lastAIDir]}`;
    $("status-text").textContent = status;

    $("aux-stats").textContent =
      ai.running || game.gameOver
        ? `${game.movesPerSecond.toFixed(1)} mv/s · ${fmtTime(game.elapsedSeconds)}`
        : "";

    const startBtn = $<HTMLButtonElement>("startpause");
    startBtn.textContent = ai.running ? "Pause" : "Start AI";
    startBtn.disabled = game.gameOver || !ai.ready;
    $<HTMLButtonElement>("step").disabled =
      ai.running || ai.thinking || game.gameOver || !ai.ready;

    const ov = $("overlay");
    if (game.gameOver) {
      renderOverlayStats();
      ov.classList.remove("hidden");
    } else {
      ov.classList.add("hidden");
    }

    setSegActive("speed", "speed", ai.speed);
    setSegActive("depth", "depth", String(ai.depth));
  }

  function newGame(): void {
    ai.stop();
    game.newGame();
    render();
  }

  // --- Controls ---
  $("newgame").addEventListener("click", newGame);
  $("overlay-newgame").addEventListener("click", newGame);
  $("startpause").addEventListener("click", () => ai.toggle());
  $("step").addEventListener("click", () => void ai.step());
  $("resetbest").addEventListener("click", () => {
    game.resetBest();
    render();
  });

  $("speed").querySelectorAll("button").forEach((b) => {
    b.addEventListener("click", () => ai.setSpeed((b as HTMLElement).dataset.speed as Speed));
  });
  $("depth").querySelectorAll("button").forEach((b) => {
    b.addEventListener("click", () => ai.setDepth(Number((b as HTMLElement).dataset.depth)));
  });

  // --- Keyboard ---
  const KEY_DIR: Record<string, Dir> = {
    ArrowUp: 0,
    ArrowRight: 1,
    ArrowDown: 2,
    ArrowLeft: 3,
  };
  window.addEventListener("keydown", (e) => {
    if (e.key in KEY_DIR) {
      e.preventDefault();
      if (!ai.running && !game.gameOver) {
        game.move(KEY_DIR[e.key]);
        render();
      }
      return;
    }
    switch (e.key) {
      case " ":
        e.preventDefault();
        ai.toggle();
        break;
      case "s":
      case "S":
        void ai.step();
        break;
      case "n":
      case "N":
        newGame();
        break;
      case "+":
      case "=":
        cycleSpeed(1);
        break;
      case "-":
      case "_":
        cycleSpeed(-1);
        break;
    }
  });

  const SPEEDS: Speed[] = ["slow", "normal", "fast", "turbo"];
  function cycleSpeed(delta: number): void {
    const idx = SPEEDS.indexOf(ai.speed);
    const next = Math.max(0, Math.min(SPEEDS.length - 1, idx + delta));
    ai.setSpeed(SPEEDS[next]);
  }

  // Keep the elapsed/mv-s readout live while the AI runs.
  setInterval(() => {
    if (ai.running) {
      $("aux-stats").textContent = `${game.movesPerSecond.toFixed(1)} mv/s · ${fmtTime(game.elapsedSeconds)}`;
    }
  }, 250);

  render();
}

void main();
