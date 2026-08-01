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
to newline-separated snapshots in that mode. Live-region width is cached after its first query.
Size detection is best effort: it honors
`COLUMNS`/`LINES`, then tries `stty size` through `/dev/tty` on macOS and Linux.
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

/-- Query terminal width, falling back to the layout library's default width. -/
def terminalWidth : IO Nat := do
  match ← terminalSize with
  | some size => pure size.columns
  | none => pure Layout.defaultWidth

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

/-- Render styled text at a supplied width, redraw a multi-line region, and flush stdout. -/
def updateTextAtWidth (state : LiveRegion) (width : Nat) (text : Text)
    (choice : ColorChoice := .auto) : IO LiveRegion := do
  (state.setWidth width).update (← TermColor.render (Layout.wrapLines width text) choice)

/-- Render styled text at the current terminal width, redraw the region, and flush stdout. -/
def updateText (state : LiveRegion) (text : Text)
    (choice : ColorChoice := .auto) : IO LiveRegion := do
  let width ← match state.width with
    | some width => pure width
    | none => terminalWidth
  state.updateTextAtWidth width text choice

/-- Leave the live region in place and move to the next line. -/
def finish (state : LiveRegion) : IO LiveRegion := do
  let (output, next) := state.finishSequence
  write output
  flush
  pure next

end LiveRegion

/-- A live progress bar driven by `termcolor-widgets`. -/
structure LiveProgress where
  private region : LiveRegion
  config : Widgets.ProgressConfig
  state : Widgets.ProgressState := {}

namespace LiveProgress

/-- Start an inactive live progress bar. -/
def start (config : Widgets.ProgressConfig := {}) : LiveProgress :=
  { region := LiveRegion.start, config }

/-- The current pure progress-bar view. -/
def view (live : LiveProgress) : Text :=
  Widgets.progressBar live.config live.state

/-- Render and display the supplied progress state. -/
def update (live : LiveProgress) (state : Widgets.ProgressState)
    (choice : ColorChoice := .auto) : IO LiveProgress := do
  let region ← live.region.updateText (Widgets.progressBar live.config state) choice
  pure { live with region, state }

/-- Finish a live progress bar. -/
def finish (live : LiveProgress) : IO LiveProgress := do
  let region ← live.region.finish
  pure { live with region }

end LiveProgress

/-- A live indeterminate progress bar for work with no known total. -/
structure LiveIndeterminateProgress where
  private region : LiveRegion
  config : Widgets.ProgressConfig
  state : Widgets.IndeterminateProgressState := {}

namespace LiveIndeterminateProgress

/-- Start an inactive indeterminate progress bar. -/
def start (config : Widgets.ProgressConfig := {}) : LiveIndeterminateProgress :=
  { region := LiveRegion.start, config }

/-- The current pure indeterminate progress-bar view. -/
def view (live : LiveIndeterminateProgress) : Text :=
  Widgets.indeterminateProgressBar live.config live.state

/-- Render and display the supplied indeterminate progress state. -/
def update (live : LiveIndeterminateProgress)
    (state : Widgets.IndeterminateProgressState)
    (choice : ColorChoice := .auto) : IO LiveIndeterminateProgress := do
  let region ← live.region.updateText
    (Widgets.indeterminateProgressBar live.config state) choice
  pure { live with region, state }

/-- Advance and display an indeterminate progress bar. -/
def tick (live : LiveIndeterminateProgress)
    (choice : ColorChoice := .auto) : IO LiveIndeterminateProgress :=
  live.update { live.state with frame := live.state.frame + 1 } choice

/-- Finish a live indeterminate progress bar. -/
def finish (live : LiveIndeterminateProgress) : IO LiveIndeterminateProgress := do
  let region ← live.region.finish
  pure { live with region }

end LiveIndeterminateProgress

/-- A live spinner driven by `termcolor-widgets`. -/
structure LiveSpinner where
  private region : LiveRegion
  config : Widgets.SpinnerConfig
  state : Widgets.SpinnerState := {}

namespace LiveSpinner

/-- Start an inactive live spinner. -/
def start (config : Widgets.SpinnerConfig := {}) : LiveSpinner :=
  { region := LiveRegion.start, config }

/-- The current pure spinner view. -/
def view (live : LiveSpinner) : Text :=
  Widgets.renderSpinner live.config live.state

/-- Render and display the supplied spinner state. -/
def update (live : LiveSpinner) (state : Widgets.SpinnerState)
    (choice : ColorChoice := .auto) : IO LiveSpinner := do
  let region ← live.region.updateText (Widgets.renderSpinner live.config state) choice
  pure { live with region, state }

/-- Advance and display a live spinner. -/
def tick (live : LiveSpinner) (choice : ColorChoice := .auto) : IO LiveSpinner :=
  live.update { live.state with frame := live.state.frame + 1 } choice

/-- Finish a live spinner. -/
def finish (live : LiveSpinner) : IO LiveSpinner := do
  let region ← live.region.finish
  pure { live with region }

end LiveSpinner

/-- A live status message driven by `termcolor-widgets`. -/
structure LiveStatus where
  private region : LiveRegion
  kind : Widgets.StatusKind
  message : Text := Text.empty

namespace LiveStatus

/-- Start an inactive live status message. -/
def start (kind : Widgets.StatusKind := .info) : LiveStatus :=
  { region := LiveRegion.start, kind }

/-- The current pure status view. -/
def view (live : LiveStatus) : Text :=
  Widgets.renderStatus live.kind live.message

/-- Render and display a new status message. -/
def update (live : LiveStatus) (kind : Widgets.StatusKind) (message : Text)
    (choice : ColorChoice := .auto) : IO LiveStatus := do
  let next := { live with kind, message }
  let region ← live.region.updateText next.view choice
  pure { next with region }

/-- Finish a live status message. -/
def finish (live : LiveStatus) : IO LiveStatus := do
  let region ← live.region.finish
  pure { live with region }

end LiveStatus

/-- A live table driven by `termcolor-widgets` and `termcolor-layout`. -/
structure LiveTable where
  private region : LiveRegion
  widths : List Nat
  gap : Nat := 2
  alignments : List Layout.Alignment := []
  rows : List (List Text) := []

namespace LiveTable

/-- Start an inactive live table with fixed display widths. -/
def start (widths : List Nat) (gap : Nat := 2)
    (alignments : List Layout.Alignment := []) : LiveTable :=
  { region := LiveRegion.start, widths, gap, alignments }

/-- The current pure table view. -/
def view (live : LiveTable) : Text :=
  Widgets.renderTable live.widths live.rows live.gap live.alignments

/-- Render and display new table rows. -/
def update (live : LiveTable) (rows : List (List Text))
    (choice : ColorChoice := .auto) : IO LiveTable := do
  let next := { live with rows }
  let region ← live.region.updateText next.view choice
  pure { next with region }

/-- Finish a live table. -/
def finish (live : LiveTable) : IO LiveTable := do
  let region ← live.region.finish
  pure { live with region }

end LiveTable

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
