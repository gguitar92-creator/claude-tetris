# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Vanilla-JS Tetris rendered on HTML5 Canvas. No dependencies, no `package.json`, no build step, no test suite, no linter — three files (`index.html`, `style.css`, `game.js`) loaded directly by the browser.

## Running

```bash
open index.html            # macOS — works from file://, no server needed
python3 -m http.server 8000   # or any static server, then open localhost:8000
```

There is nothing to build, install, lint, or test. "Verifying a change" means loading the page in a browser and playing.

## Architecture

All game logic lives in `game.js` as top-level functions over module-scoped mutable state (`board`, `current`, `next`, `score`, `lines`, `level`, `paused`, `gameOver`, `dropInterval`, `dropAccum`, `animId`). There are no classes, modules, or exports — functions read and write these globals directly, so any new logic should follow the same style rather than introducing an abstraction layer.

Key structures:

- `board` — `ROWS × COLS` array of ints. `0` = empty; `1–7` doubles as both the piece type and the index into `COLORS`. `PIECES[type]` cells contain that same integer, so merging a piece into the board is a straight copy of its non-zero cells.
- `current` / `next` — `{ type, shape, x, y }`. `shape` is a mutable square matrix owned by the piece; `randomPiece()` deep-copies from `PIECES` so rotation never mutates the templates.
- Rotation is CW transpose-and-reverse (`rotateCW`) plus a fixed wall-kick ladder `[0, -1, 1, -2, 2]` in `tryRotate()` — not SRS. There is no rotation-state tracking.
- `clearLines()` mutates `board` in place with `splice`/`unshift` and re-checks the same row index (`r++` after a clear), which is why the loop runs bottom-up.

Control flow: `init()` resets all state and starts `loop()`; `loop()` is a `requestAnimationFrame` accumulator that advances one row when `dropAccum >= dropInterval`, then redraws the whole frame. `lockPiece()` → `merge()` → `clearLines()` → `spawn()`; `spawn()` promotes `next` to `current` and calls `endGame()` if the new piece already collides. Pause/game-over stop the RAF loop via `cancelAnimationFrame(animId)` rather than gating inside `loop()`.

Rendering redraws everything every frame — grid, settled board, ghost piece (alpha `0.2`, position from `ghostY()`), then the active piece. `drawNext()` is called only on spawn, not per frame.

## Things that bite

- **Canvas size is hardcoded in HTML.** `<canvas id="board" width="300" height="600">` must equal `COLS * BLOCK` × `ROWS * BLOCK`. Changing `COLS`, `ROWS`, or `BLOCK` in `game.js` without updating `index.html` silently clips or letterboxes the board. Same for `#next-canvas` (120×120 = 4×4 cells at `NB = 30`, hardcoded inside `drawNext`).
- **Scoring depends on ordering.** `clearLines()` bumps `level` *after* applying `score += LINE_SCORES[cleared] * level`, so a clear is scored at the pre-clear level. Preserve that if you touch it.
- **Known bug:** `togglePause()` shows the overlay when pausing but never re-hides it when resuming — only `init()` calls `overlay.classList.add('hidden')`. Resuming restarts the loop underneath a still-visible "PAUSA" overlay.

## Conventions

- `'use strict'` at the top of `game.js`; ES6+ used freely (arrow functions, spread, `Array.from`, template literals) with no transpilation.
- User-facing strings in the HTML and in overlay text are **Spanish** ("PAUSA", "Puntuación", "Reiniciar", control hints); HUD labels and code identifiers are English. Match that split.
- The README is Spanish and documents mechanics, controls, and the tunable-constants table — update it when changing gameplay parameters or controls.
