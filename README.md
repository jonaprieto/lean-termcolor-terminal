# termcolor-terminal

[![CI](https://github.com/jonaprieto/lean-termcolor-terminal/workflows/CI/badge.svg)](https://github.com/jonaprieto/lean-termcolor-terminal/actions/workflows/ci.yml)
[![Lean 4](https://img.shields.io/badge/Lean%204-library-5f5f5f)](lean-toolchain)
[![License](https://img.shields.io/badge/license-Apache--2.0-green)](LICENSE)

Terminal control and live IO helpers for the [`termcolor`](https://github.com/jonaprieto/lean-termcolor)
stack. Pure ANSI sequences are exposed alongside stdout output, flushing, one-line redraws,
multi-line regions, and widget-backed live progress and spinner objects.

```lean
import TermColor.Terminal

open TermColor
open TermColor.Terminal

def main : IO Unit := do
  let region := LiveRegion.start
  let region ← region.updateText (Text.styled "working..." Style.cyan)
  let _ ← region.updateText (Text.styled "done" Style.green)
  let _ ← region.finish
```

`terminalSize` queries the current `/dev/tty` size first. If no TTY is available, it falls back to
`COLUMNS` and `LINES`, returning `none` when no terminal size is available. Results are shared for
100 ms so live animations do not fork `stty` on every frame.

Cursor-control helpers are no-ops when stdout is redirected or `TERM` is `dumb`/`unknown`.
Live objects use newline-separated snapshots in that mode, so pipes and CI logs do not receive
cursor escape sequences. `stdoutSupportsControl` exposes the same policy to callers.

`LiveRegion` redraws a one- or multi-line `Text` value at the current terminal width, and `LiveProgress`,
`LiveSpinner`, `LiveIndeterminateProgress`, `LiveStatus`, and `LiveTable` connect
[`termcolor-widgets`](https://github.com/jonaprieto/lean-termcolor-widgets) to those live updates.
Styled text is rendered through `TermColor.Detect`, while
[`termcolor-layout`](https://github.com/jonaprieto/lean-termcolor-layout) supplies width-aware
boxes, columns, and the default terminal width. [`argus`](https://github.com/jonaprieto/lean-argus)
uses this terminal layer for command help and completion output.

## TUI input core

`parseKey` decodes complete arrow, Home/End, page, reverse-tab, Enter, Tab, Escape, Backspace,
control, and character sequences into the pure `termcolor-widgets` `Key` type. `readKey` reads the
same keys directly from a TTY, while `parseEvent`/`readEvent` add SGR mouse events. `withRawInput`
scopes character-at-a-time mode and restores the previous terminal settings; `withMouseCapture`
does the same for explicit mouse reporting.
`moveFocus` wraps an ordered set of application-owned focus slots.

`Screen` also supports full-screen frames: a `Frame` carries rendered `Text`, stable application
`HitRegion`s, and optional focus information. `Screen.renderFrame` updates the visible lines and
hit regions together. `hitTest` accepts only a left-button press, uses the protocol's one-based
coordinates, and returns the first matching region ID; release and wheel events remain available
to the application without causing duplicate clicks.

## Terminal behavior

The live path uses ANSI/VT control sequences on capable TTYs. It degrades to newline-separated
snapshots for pipes, CI logs, `TERM=dumb`, and `TERM=unknown`, keeping redirected output readable
and free of cursor escapes. Terminal sizing uses the current `/dev/tty` dimensions first and
`COLUMNS`/`LINES` as the non-TTY fallback. Live regions re-query the terminal width through the
100 ms cache, so periodic progress and spinner updates reflow after a window resize without paying
the subprocess cost every frame. `Screen` retains rendered lines and emits only changed-line
updates for small full-screen apps. Use `updateTextAtWidth` when a fixed width is required.

## Demo

Run the demo from an interactive terminal to enter the direct-key TUI first. It contains `Form`,
`Boxes`, and `About` tabs: `Tab` moves focus, `Left`/`Right` switches tabs or edits controls,
`Enter` activates Save, and `Esc` exits. The `Boxes` tab demonstrates nested and stacked titled
boxes arranged with `Layout.columns`. The demo then continues with live progress, spinner, status,
and table examples, followed by a full-screen two-job session. That session owns one `Screen`,
coalesces worker messages before rendering, supports keyboard/mouse expansion and scrolling, and
restores raw input, mouse capture, cursor, and alternate-screen state on exit. Non-TTY, CI, and
forced non-interactive runs show deterministic static previews and skip live animations.

Build and run the demo:

```sh
lake build TermColor.Terminal TermColor.Terminal.Properties demo
lake exe demo
```

The separate `TermColor.Terminal.Properties` library machine-checks the pure sequence and live-object laws.
`scripts/check-axioms.py` reports the axioms every one of them depends on and fails the build on
anything unexpected. Laws proved by `native_decide` trust the compiler rather than the kernel, so each
is named in an explicit allowlist instead of passing unnoticed.
Most proofs use kernel `decide`; size parsing and string-heavy redraw cases use `native_decide` because
Lean 4.28 does not reduce those strings in the kernel. CI checks that allowlisted axiom footprint.
Force the static demo with `TERMCOLOR_TERMINAL_NONINTERACTIVE=1 lake exe demo`. Cell-granularity
screen diffing remains outside this small line-oriented output layer.

## License

Apache-2.0.
