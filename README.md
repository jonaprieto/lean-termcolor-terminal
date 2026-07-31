# termcolor-terminal

Small terminal control and IO helpers for [`termcolor`](https://github.com/jonaprieto/lean-termcolor).
Pure ANSI sequences are exposed alongside stdout output, flushing, one-line redraws, and a
best-effort terminal-size query.

```lean
import TermColorTerminal

open TermColor
open TermColor.Terminal

def main : IO Unit := do
  let line := LiveLine.start
  let line ← line.update (Text.render RenderTarget.ansi16
    (Text.styled "working..." Style.cyan))
  let _ ← line.update (Text.render RenderTarget.ansi16
    (Text.styled "done" Style.green))
  let _ ← line.finish
```

`terminalSize` first honors `COLUMNS` and `LINES`. If those are unavailable, it invokes `stty size`
through `/dev/tty` on macOS/Linux and returns `none` when no terminal size is available.

Build and run the demo:

```sh
lake build TermColorTerminal TerminalProperties demo
lake exe demo
```

The separate `TerminalProperties` library machine-checks the pure sequence and live-line laws.
This package intentionally does not provide progress widgets, raw mode, or full-screen buffers;
those belong in higher layers and can be added when a concrete use case requires them.

## License

Apache-2.0.
