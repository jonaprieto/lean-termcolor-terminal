# termcolor-terminal

[![CI](https://github.com/jonaprieto/lean-termcolor-terminal/actions/workflows/ci.yml/badge.svg)](https://github.com/jonaprieto/lean-termcolor-terminal/actions/workflows/ci.yml)
[![Lean 4](https://img.shields.io/badge/Lean%204-library-5f5f5f)](lean-toolchain)
[![License](https://img.shields.io/badge/license-Apache--2.0-green)](LICENSE)

Terminal control and live IO for the [`termcolor`](https://github.com/jonaprieto/lean-termcolor)
stack.

## Terminal primitives

`LiveRegion` for arbitrary pure widget views, terminal-size queries, cursor control, raw input, mouse
capture, key parsing, SGR mouse events, and deterministic non-TTY output are provided here.

`Screen` renders full-screen `Frame` values. Each frame contains rendered `Text`, stable application
owned `HitRegion`s, and optional focus information. `renderFrame` updates visible lines and hit
regions together; `hitTest` accepts left-button presses using one-based terminal coordinates.

## Composable applications

`TermColor.Terminal.UI` adds a small typed composition layer without putting IO in views:

```lean
import TermColor.Terminal

open TermColor TermColor.Terminal

def dashboard : View :=
  View.column 1
    [ View.withPrefix "summary" (View.text (Text.plain "ready"))
    , View.row 2 [View.text (Text.plain "jobs"), View.text (Text.plain "logs")] ]

def frame (size : Size) : Frame :=
  (dashboard.render { size, area := { top := 1, left := 1, width := size.columns, height := size.rows } }).toFrame
```

`Component Model Msg` separates pure rendering from typed updates and explicit commands. The
existing two-job demo uses `View.column` for independently focusable job views, while
`lineRenderer` and `bufferRenderer` provide interchangeable output backends.
Hosts can interpret returned command trees with `Command.run`; `Runtime.run` stays a small
model/view loop rather than imposing an application scheduler.

`FocusRing.fromRendered` gives composed focusables a stable traversal order, and `target` routes
keyboard events to the focused id or mouse presses through the rendered hit regions.

`Buffer` is a fixed-size pure cell surface. It preserves styled cells, handles wide glyph
continuations, emits only changed cell ranges, and falls back to a full redraw on first render or
resize. Use it when positioned or partially changing content needs it; `Screen` remains the simpler
line-oriented default. `lake exe bench` runs a warmed, repeated buffer-vs-line diff measurement at
two surface sizes.

```lean
import TermColor.Terminal

open TermColor TermColor.Terminal

def main : IO Unit := do
  let region := LiveRegion.start
  let region ← region.updateText (Text.styled "working..." Style.cyan)
  let _ ← region.updateText (Text.styled "done" Style.green)
  let _ ← region.finish
```

## Demo and build

```sh
lake build TermColor.Terminal TermColor.Terminal.Properties demo
lake exe demo
lake exe bench
TERMCOLOR_TERMINAL_NONINTERACTIVE=1 lake exe demo
```

The demo covers keyboard and mouse input, resize-aware frames, live widgets, a two-job screen, and
cleanup after exit or failure. Redirected output falls back to newline-separated snapshots.

## Related projects

[`termcolor-widgets`](https://github.com/jonaprieto/lean-termcolor-widgets) supplies pure views;
[`termcolor-repl`](https://github.com/jonaprieto/lean-termcolor-repl) supplies reusable REPL input.

## License

Apache-2.0.
