# termcolor-terminal

[![CI](https://github.com/jonaprieto/lean-termcolor-terminal/actions/workflows/ci.yml/badge.svg)](https://github.com/jonaprieto/lean-termcolor-terminal/actions/workflows/ci.yml)
[![Lean 4](https://img.shields.io/badge/Lean%204-library-5f5f5f)](lean-toolchain)
[![License](https://img.shields.io/badge/license-Apache--2.0-green)](LICENSE)

Terminal control and live IO helpers for the `termcolor` stack. Pure ANSI sequences are exposed
alongside stdout output, flushing, one-line redraws, multi-line regions, and widget-backed live
progress and spinner objects.

```lean
import TermColorTerminal

open TermColor
open TermColor.Terminal

def main : IO Unit := do
  let line := LiveLine.start
  let line ← line.updateText (Text.styled "working..." Style.cyan)
  let _ ← line.updateText (Text.styled "done" Style.green)
  let _ ← line.finish
```

`terminalSize` first honors `COLUMNS` and `LINES`. If those are unavailable, it invokes `stty size`
through `/dev/tty` on macOS/Linux and returns `none` when no terminal size is available.

`LiveLine` redraws one line, `LiveRegion` redraws a multi-line `Text` value, and `LiveProgress`,
`LiveSpinner`, `LiveStatus`, and `LiveTable` connect `termcolor-widgets` to those live updates.
Styled text is rendered through `TermColor.Detect`, while `termcolor-layout` supplies width-aware
boxes, columns, and the default terminal width.

Build and run the demo:

```sh
lake build TermColorTerminal TerminalProperties demo
lake exe demo
```

The separate `TerminalProperties` library machine-checks the pure sequence and live-object laws.
Raw keyboard mode and a full-screen retained buffer are intentionally outside this small live
output layer.

## License

Apache-2.0.
