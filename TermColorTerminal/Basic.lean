/-
Copyright (c) 2026 Jonathan Prieto-Cubides. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Jonathan Prieto-Cubides
-/

import TermColor

/-!
# TermColor.Terminal.Basic: terminal control and IO

The sequence builders are pure values. The IO helpers write to stdout and flush explicitly. Size
detection is best effort: it honors `COLUMNS`/`LINES`, then tries `stty size` through `/dev/tty` on
macOS and Linux.
-/

namespace TermColor
namespace Terminal

private def csi : String := "\u001b["

/-- Move the cursor up by `count` rows, or emit nothing for zero. -/
def cursorUpSequence (count : Nat) : String :=
  if count == 0 then "" else csi ++ toString count ++ "A"

/-- Move the cursor down by `count` rows, or emit nothing for zero. -/
def cursorDownSequence (count : Nat) : String :=
  if count == 0 then "" else csi ++ toString count ++ "B"

/-- Erase the current line and return to its first column. -/
def clearLineSequence : String := csi ++ "2K\r"

/-- Hide the terminal cursor. -/
def hideCursorSequence : String := csi ++ "?25l"

/-- Show the terminal cursor. -/
def showCursorSequence : String := csi ++ "?25h"

/-- Write text to stdout without flushing. -/
def write (text : String) : IO Unit := IO.print text

/-- Flush stdout. -/
def flush : IO Unit := do
  (← IO.getStdout).flush

private def writeFlush (text : String) : IO Unit := do
  write text
  flush

/-- Erase the current line and return to its first column. -/
def clearLine : IO Unit := writeFlush clearLineSequence

/-- Move the cursor up and flush stdout. -/
def cursorUp (count : Nat) : IO Unit := writeFlush (cursorUpSequence count)

/-- Move the cursor down and flush stdout. -/
def cursorDown (count : Nat) : IO Unit := writeFlush (cursorDownSequence count)

/-- Hide the terminal cursor and flush stdout. -/
def hideCursor : IO Unit := writeFlush hideCursorSequence

/-- Show the terminal cursor and flush stdout. -/
def showCursor : IO Unit := writeFlush showCursorSequence

/-- Whether stdout is attached to a terminal. -/
def stdoutIsTty : IO Bool := do
  (← IO.getStdout).isTty

/-- Whether stdin is attached to a terminal. -/
def stdinIsTty : IO Bool := do
  (← IO.getStdin).isTty

/-- A terminal's usable character dimensions. -/
structure Size where
  columns : Nat
  rows : Nat

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
  -- ponytail: a fixed `stty` subprocess keeps this portable; add termios FFI when raw mode or
  -- low-latency resize polling becomes a requirement.
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

/-- Query terminal dimensions, returning `none` when no size can be determined. -/
def terminalSize : IO (Option Size) := do
  let environment := environmentSize (← IO.getEnv "COLUMNS") (← IO.getEnv "LINES")
  match environment with
  | some size => pure (some size)
  | none => sttySize

/-- State for redrawing one terminal line in place. -/
structure LiveLine where
  private hasLine : Bool := false

namespace LiveLine

/-- Start an inactive live line. -/
def start : LiveLine := {}

/-- Pure output and next state for one live-line update. -/
def updateSequence (state : LiveLine) (text : String) : String × LiveLine :=
  let lead := if state.hasLine then clearLineSequence else ""
  (lead ++ text, { hasLine := true })

/-- Redraw the line and flush stdout. The text should not contain newlines. -/
def update (state : LiveLine) (text : String) : IO LiveLine := do
  let (output, next) := updateSequence state text
  write output
  flush
  pure next

/-- Pure output and next state for finishing a live line. -/
def finishSequence (state : LiveLine) : String × LiveLine :=
  (if state.hasLine then "\n" else "", {})

/-- Leave the live line in place and move to the next line. -/
def finish (state : LiveLine) : IO LiveLine := do
  let (output, next) := finishSequence state
  write output
  flush
  pure next

end LiveLine

end Terminal
end TermColor
