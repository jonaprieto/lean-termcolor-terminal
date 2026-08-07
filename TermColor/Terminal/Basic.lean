/-
Copyright (c) 2026 Jonathan Prieto-Cubides. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Jonathan Prieto-Cubides
-/

import TermColor.Detect
import TermColor.Layout
import TermColor.Widgets

/-!
# TermColor.Terminal.Basic: terminal control and IO

The sequence builders are pure values. The IO helpers write to stdout and flush explicitly. Cursor
controls are disabled for redirected output and `TERM=dumb`/`TERM=unknown`; live objects fall back
to newline-separated snapshots in that mode. Live-region width follows the terminal on each
default-width update; callers can pin it with `updateTextAtWidth`. Size detection is best effort:
it queries `/dev/tty` for the current TTY size, then falls back to `COLUMNS`/`LINES`.
-/

namespace TermColor
namespace Terminal

private def csi : String := "\u001b["

private def visibleLineCount (text : String) : Nat :=
  if text.isEmpty then 0 else text.splitOn "\n" |>.length

/-- Move the cursor up by `count` rows, or emit nothing for zero. -/
def cursorUpSequence (count : Nat) : String :=
  if count == 0 then "" else csi ++ toString count ++ "A"

/-- Move the cursor down by `count` rows, or emit nothing for zero. -/
def cursorDownSequence (count : Nat) : String :=
  if count == 0 then "" else csi ++ toString count ++ "B"

/-- Move to a one-based terminal column. -/
def cursorToColumnSequence (column : Nat) : String := csi ++ toString (column + 1) ++ "G"

/-- Erase the current line and return to its first column. -/
def clearLineSequence : String := csi ++ "2K\r"

/-- Clear the visible screen and move the cursor to its home position. -/
def clearScreenSequence : String := csi ++ "2J" ++ csi ++ "H"

/-- Save the current cursor position. -/
def saveCursorSequence : String := csi ++ "s"

/-- Restore the previously saved cursor position. -/
def restoreCursorSequence : String := csi ++ "u"

/-- Enter the terminal's alternate screen buffer. -/
def enterAlternateScreenSequence : String := csi ++ "?1049h"

/-- Leave the terminal's alternate screen buffer. -/
def exitAlternateScreenSequence : String := csi ++ "?1049l"

/-- Hide the terminal cursor. -/
def hideCursorSequence : String := csi ++ "?25l"

/-- Show the terminal cursor. -/
def showCursorSequence : String := csi ++ "?25h"

/-- Whether a TTY and terminal declaration allow cursor-control sequences. -/
def terminalControlAllowed (isTty : Bool) (term : Option String) : Bool :=
  if !isTty then false else
    match term with
    | some "dumb" | some "unknown" => false
    | _ => true

private def terminalControlEnabled : IO Bool := do
  pure (terminalControlAllowed (← (← IO.getStdout).isTty) (← IO.getEnv "TERM"))

/-- Write text to stdout without flushing. -/
def write (text : String) : IO Unit := IO.print text

/-- Flush stdout. -/
def flush : IO Unit := do
  (← IO.getStdout).flush

private def writeFlush (text : String) : IO Unit := do
  write text
  flush

private def writeControl (sequence : String) : IO Unit := do
  if ← terminalControlEnabled then
    writeFlush sequence

/-- Render styled text using terminal detection and write it without a newline. -/
def writeText (text : Text) (choice : ColorChoice := .auto) : IO Unit := do
  write (← TermColor.render text choice)

/-- Render styled text using terminal detection and write it with a newline. -/
def writeTextLine (text : Text) (choice : ColorChoice := .auto) : IO Unit := do
  write (← TermColor.render (text ++ Text.plain "\n") choice)

/-- Erase the current line and return to its first column. -/
def clearLine : IO Unit := writeControl clearLineSequence

/-- Clear the visible screen and flush stdout. -/
def clearScreen : IO Unit := writeControl clearScreenSequence

/-- Save the cursor position and flush stdout. -/
def saveCursor : IO Unit := writeControl saveCursorSequence

/-- Restore the cursor position and flush stdout. -/
def restoreCursor : IO Unit := writeControl restoreCursorSequence

/-- Enter the alternate screen buffer and flush stdout. -/
def enterAlternateScreen : IO Unit := writeControl enterAlternateScreenSequence

/-- Leave the alternate screen buffer and flush stdout. -/
def exitAlternateScreen : IO Unit := writeControl exitAlternateScreenSequence

/-- Move the cursor up and flush stdout. -/
def cursorUp (count : Nat) : IO Unit := writeControl (cursorUpSequence count)

/-- Move the cursor down and flush stdout. -/
def cursorDown (count : Nat) : IO Unit := writeControl (cursorDownSequence count)

/-- Move to a one-based terminal column and flush stdout. -/
def cursorToColumn (column : Nat) : IO Unit := writeControl (cursorToColumnSequence column)

/-- Hide the terminal cursor and flush stdout. -/
def hideCursor : IO Unit := writeControl hideCursorSequence

/-- Show the terminal cursor and flush stdout. -/
def showCursor : IO Unit := writeControl showCursorSequence

/-- Whether stdout is attached to a terminal. -/
def stdoutIsTty : IO Bool := do
  (← IO.getStdout).isTty

/-- Whether stdout is a TTY suitable for cursor-control sequences. -/
def stdoutSupportsControl : IO Bool := terminalControlEnabled

/-- Whether stdin is attached to a terminal. -/
def stdinIsTty : IO Bool := do
  (← IO.getStdin).isTty

/-- A terminal's usable character dimensions. -/
structure Size where
  columns : Nat
  rows : Nat
  deriving BEq, DecidableEq, Repr, Inhabited

private def parsePositiveNat (text : String) : Option Nat :=
  text.trimAscii.toNat? |>.filter (· > 0)

/-- Parse the `rows columns` output convention used by `stty size`. -/
def parseSize (output : String) : Option Size :=
  let values := output.splitToList (·.isWhitespace) |>.filterMap parsePositiveNat
  match values with
  | rows :: columns :: _ => some { columns, rows }
  | _ => none

private def environmentSize (columns rows : Option String) : Option Size := do
  let columns ← columns >>= parsePositiveNat
  let rows ← rows >>= parsePositiveNat
  pure { columns, rows }

private def sttySize : IO (Option Size) := do
  -- ponytail: a fixed `stty` subprocess keeps this portable; add termios FFI only if signal-driven
  -- resize notifications become a requirement.
  try
    let output ← IO.Process.output {
      cmd := "sh"
      args := #["-c", "stty size < /dev/tty"]
    }
    if output.exitCode == 0 then
      pure (parseSize output.stdout)
    else
      pure none
  catch _ => pure none

private def terminalSizeCacheNanos : Nat := 250_000_000

initialize terminalSizeCache : IO.Ref (Option (Nat × Option Size)) ← IO.mkRef none

private def uncachedTerminalSize : IO (Option Size) := do
  match ← sttySize with
  | some size => pure (some size)
  | none =>
    pure (environmentSize (← IO.getEnv "COLUMNS") (← IO.getEnv "LINES"))

/-- Query terminal dimensions, returning `none` when no size can be determined. -/
def terminalSize : IO (Option Size) := do
  let now ← IO.monoNanosNow
  match ← terminalSizeCache.get with
  | some (cachedAt, size) =>
      if now - cachedAt < terminalSizeCacheNanos then pure size
      else
        let size ← uncachedTerminalSize
        terminalSizeCache.set (some (now, size))
        pure size
  | none =>
      let size ← uncachedTerminalSize
      terminalSizeCache.set (some (now, size))
      pure size

-- ponytail: one shared 250ms cache keeps animated updates cheap; add signal-driven invalidation
-- or termios FFI if resize latency below 250ms becomes a customer requirement.

/-- Query terminal width, falling back to the layout library's default width. -/
def terminalWidth : IO Nat := do
  match ← terminalSize with
  | some size => pure size.columns
  | none => pure Layout.defaultWidth

private def cursorToRowSequence (row : Nat) : String :=
  csi ++ toString (row + 1) ++ ";1H"

/-- A stable application-owned rectangle in one-based terminal coordinates. -/
structure HitRegion where
  id : String
  top : Nat
  bottom : Nat
  left : Nat
  right : Nat
  deriving BEq, DecidableEq, Repr

/-- Whether a one-based terminal coordinate lies inside a hit region. -/
def HitRegion.contains (region : HitRegion) (row column : Nat) : Bool :=
  region.top ≤ row && row ≤ region.bottom && region.left ≤ column && column ≤ region.right

/-- A pure frame supplied to `Screen.renderFrame`. -/
structure Frame where
  text : Text := Text.empty
  hitRegions : List HitRegion := []
  focus : Option String := none
  deriving BEq, DecidableEq, Repr

instance : Inhabited Frame := ⟨{}⟩

/-- Retained line-oriented screen state for small full-screen applications. -/
structure Screen where
  private previous : List String := []
  private size : Option Size := none
  frame : Frame := {}

namespace Screen

/-- Empty screen state, useful when testing `diffSequence` without terminal IO. -/
def empty : Screen := {}

/-- Start a screen and capture the current terminal size. -/
def start : IO Screen := do
  pure { size := ← terminalSize }

/-- Pure line-granularity diff from the previous screen to `next`. -/
def diffSequence (screen : Screen) (next : List String) : String × Screen :=
  let count := max screen.previous.length next.length
  let pieces := (List.range count).foldl (fun pieces row =>
    let oldLine := screen.previous.getD row ""
    let newLine := next.getD row ""
    if oldLine == newLine then pieces
    else (cursorToRowSequence row ++ clearLineSequence ++ newLine) :: pieces) []
  (String.join pieces.reverse, { screen with previous := next })

private def renderedLines (size : Option Size) (text : Text) : Text :=
  let wrapped := Layout.splitLines (Layout.wrapLines
    (size.map (·.columns) |>.getD Layout.defaultWidth) text)
  let lines := match size with
    | some size => wrapped.take (max 1 size.rows)
    | none => wrapped
  Layout.joinLines lines

/-- Render a frame, atomically retaining its hit regions after the write succeeds. -/
def renderFrame (screen : Screen) (frame : Frame) (choice : ColorChoice := .auto) : IO Screen := do
  let size := (← terminalSize).orElse (fun _ => screen.size)
  if screen.frame == frame && screen.size == size then
    return screen
  let rendered ← TermColor.render (renderedLines size frame.text) choice
  let next := rendered.splitOn "\n"
  if ← terminalControlEnabled then
    let (output, nextScreen) := screen.diffSequence next
    write output
    flush
    let nextScreen := { nextScreen with size := size }
    pure { nextScreen with frame }
  else
    write (rendered ++ "\n")
    flush
    let nextScreen := { screen with previous := next }
    let nextScreen := { nextScreen with size := size }
    pure { nextScreen with frame }

/-- Render a screen, rewriting only lines whose visible text changed. -/
def render (screen : Screen) (text : Text) (choice : ColorChoice := .auto) : IO Screen :=
  screen.renderFrame { text } choice

/-- Finish a screen and leave the cursor below its last rendered line. -/
def finish (screen : Screen) : IO Screen := do
  if ← terminalControlEnabled then
    write (cursorToRowSequence screen.previous.length ++ "\n")
    flush
  pure {}

end Screen

/-- Enable SGR mouse events, optionally including drag reporting. -/
def mouseCaptureSequence (enabled drag : Bool) : String :=
  if enabled then
    csi ++ "?" ++ (if drag then "1002" else "1000") ++ "h" ++ csi ++ "?1006h"
  else
    csi ++ "?1006l" ++ csi ++ "?" ++ (if drag then "1002" else "1000") ++ "l"

/-- Enable mouse reporting when stdout is a capable terminal. -/
def enableMouse (drag : Bool := false) : IO Unit :=
  writeControl (mouseCaptureSequence true drag)

/-- Disable mouse reporting. -/
def disableMouse (drag : Bool := false) : IO Unit :=
  writeControl (mouseCaptureSequence false drag)

/-- Scope mouse reporting and restore the terminal mode even when the action fails. -/
def withMouseCapture {α : Type} (action : IO α) (drag : Bool := false) : IO α := do
  enableMouse drag
  try action finally disableMouse drag

/-- State for redrawing a multi-line terminal region in place. -/
structure LiveRegion where
  lineCount : Nat := 0
  private width : Option Nat := none

namespace LiveRegion

/-- Start an inactive live region. -/
def start : LiveRegion := {}

/-- Use a supplied width for subsequent text updates. -/
def setWidth (state : LiveRegion) (width : Nat) : LiveRegion :=
  { state with width := some width }

private def clearBelowSequence (count : Nat) : String :=
  if count == 0 then "" else
    let output := (List.range count).foldl
      (fun result _ => result ++ cursorDownSequence 1 ++ clearLineSequence) ""
    output ++ cursorUpSequence count ++ "\r"

private def clearAndWriteLines (text : String) : String :=
  String.join (((text.splitOn "\n").map fun line => clearLineSequence ++ line).intersperse "\n")

/-- Pure output and next state for a multi-line redraw. -/
def updateSequence (state : LiveRegion) (text : String) : String × LiveRegion :=
  let oldCount := state.lineCount
  let newCount := visibleLineCount text
  let lead := if oldCount == 0 then "" else cursorUpSequence (oldCount - 1) ++ "\r"
  let body := if newCount == 0 then
      if oldCount == 0 then "" else clearLineSequence
    else clearAndWriteLines text
  let trailingCount := if oldCount > newCount then
      if newCount == 0 then oldCount - 1 else oldCount - newCount
    else 0
  let trailing := clearBelowSequence trailingCount
  (lead ++ body ++ trailing, { state with lineCount := newCount })

/-- Pure output and next state for finishing a live region. -/
def finishSequence (state : LiveRegion) : String × LiveRegion :=
  (if state.lineCount == 0 then "" else "\n", {})

/-- Redraw a multi-line region and flush stdout. -/
def update (state : LiveRegion) (text : String) : IO LiveRegion := do
  if ← terminalControlEnabled then
    let (output, next) := state.updateSequence text
    write output
    flush
    pure next
  else
    write ((if state.lineCount == 0 then "" else "\n") ++ text)
    flush
    pure { state with lineCount := visibleLineCount text }

private def renderTextAtWidth (width : Nat) (text : Text) (choice : ColorChoice) : IO String := do
  TermColor.render (Layout.wrapLines width text) choice

/-- Render styled text at a supplied width, redraw a multi-line region, and flush stdout. -/
def updateTextAtWidth (state : LiveRegion) (width : Nat) (text : Text)
    (choice : ColorChoice := .auto) : IO LiveRegion := do
  (state.setWidth width).update (← renderTextAtWidth width text choice)

/-- Render styled text at the current terminal width, redraw the region, and flush stdout.

When the region has no explicit width, the terminal is queried for every update so live output
can reflow after a window resize. -/
def updateText (state : LiveRegion) (text : Text)
    (choice : ColorChoice := .auto) : IO LiveRegion := do
  let width ← match state.width with
    | some width => pure width
    | none => terminalWidth
  state.update (← renderTextAtWidth width text choice)

/-- Leave the live region in place and move to the next line. -/
def finish (state : LiveRegion) : IO LiveRegion := do
  let (output, next) := state.finishSequence
  write output
  flush
  pure next

end LiveRegion

/-- Hide the cursor for an action and restore it even when the action fails. -/
def withHiddenCursor {α : Type} (action : IO α) : IO α := do
  hideCursor
  try action finally showCursor

/-- Run an action in the alternate screen buffer and restore the normal screen afterward. -/
def withAlternateScreen {α : Type} (action : IO α) : IO α := do
  enterAlternateScreen
  try action finally exitAlternateScreen

end Terminal
end TermColor
