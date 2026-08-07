# termcolor-terminal

[![CI](https://github.com/jonaprieto/lean-termcolor-terminal/actions/workflows/ci.yml/badge.svg)](https://github.com/jonaprieto/lean-termcolor-terminal/actions/workflows/ci.yml)
[![Lean 4](https://img.shields.io/badge/Lean%204-library-5f5f5f)](lean-toolchain)
[![License](https://img.shields.io/badge/license-Apache--2.0-green)](LICENSE)

Terminal control and live IO for the [`termcolor`](https://github.com/jonaprieto/lean-termcolor)
stack.

## Terminal primitives

`LiveRegion`, live progress and spinner objects, terminal-size queries, cursor control, raw input,
mouse capture, key parsing, SGR mouse events, and deterministic non-TTY output are provided here.

`Screen` renders full-screen `Frame` values. Each frame contains rendered `Text`, stable application
owned `HitRegion`s, and optional focus information. `renderFrame` updates visible lines and hit
regions together; `hitTest` accepts left-button presses using one-based terminal coordinates.

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
TERMCOLOR_TERMINAL_NONINTERACTIVE=1 lake exe demo
```

The demo covers keyboard and mouse input, resize-aware frames, live widgets, a two-job screen, and
cleanup after exit or failure. Redirected output falls back to newline-separated snapshots.

## Related projects

[`termcolor-widgets`](https://github.com/jonaprieto/lean-termcolor-widgets) supplies pure views;
[`termcolor-repl`](https://github.com/jonaprieto/lean-termcolor-repl) supplies reusable REPL input.

## License

Apache-2.0.
