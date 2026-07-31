/-
Copyright (c) 2026 Jonathan Prieto-Cubides. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Jonathan Prieto-Cubides
-/

import TermColorTerminal

open TermColor
open TermColor.Layout
open TermColor.Terminal
open TermColor.Widgets

private def showSequence (label sequence : String) : IO Unit :=
  IO.println s!"{label}: {repr sequence}"

private def liveDemo : IO Unit := do
  IO.println "live progress and spinner:"
  hideCursor
  try
    let mut region := LiveRegion.start
    for current in [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10] do
      let labelStyle := if current == 10 then Style.green else Style.cyan
      let width ← terminalWidth
      let barWidth := max 10 (min 40 (max 1 (width - 20)))
      let progress := progressBar { width := barWidth }
        { current, total := 10, label := Text.styled "download" labelStyle }
      let spinner := renderSpinner { prefixText := Text.plain "  " }
        { frame := current, label := Text.plain "working" }
      region ← region.updateText (progress ++ Text.plain "\n" ++ spinner)
      IO.sleep 150
    let _ ← region.finish
    let unknown := LiveIndeterminateProgress.start { width := 20, indeterminateWidth := 8 }
    let mut unknown := unknown
    for frame in List.range 25 do
      unknown ← unknown.update
        { frame, label := Text.styled "indexing (unknown)" Style.cyan }
      IO.sleep 150
    let _ ← unknown.finish
    let status := LiveStatus.start
    let status ← status.update .warning (Text.plain "using a fallback")
    IO.sleep 150
    let _ ← status.update .success (Text.plain "ready")
    let _ ← status.finish
  finally
    showCursor

private def liveRegionDemo : IO Unit := do
  IO.println "live region:"
  hideCursor
  try
    let table := LiveTable.start [12, 10]
    let table ← table.update
      [[Text.styled "task" Style.bold, Text.styled "status" Style.bold],
       [Text.plain "download", Text.styled "running" Style.yellow]]
    let _ ← table.update
      [[Text.styled "task" Style.bold, Text.styled "status" Style.bold],
       [Text.plain "download", Text.styled "done" Style.green]]
    let _ ← table.finish
  finally
    showCursor

def main : IO Unit := do
  IO.println "termcolor-terminal"
  IO.println "pure control sequences:"
  showSequence "cursor up 2" (cursorUpSequence 2)
  showSequence "cursor down 2" (cursorDownSequence 2)
  showSequence "clear line" clearLineSequence
  showSequence "hide cursor" hideCursorSequence
  showSequence "show cursor" showCursorSequence
  showSequence "clear screen" clearScreenSequence
  showSequence "alternate screen in" enterAlternateScreenSequence
  showSequence "alternate screen out" exitAlternateScreenSequence
  IO.println s!"stdout is a TTY: {← stdoutIsTty}"
  IO.println s!"stdin is a TTY: {← stdinIsTty}"
  match ← terminalSize with
  | some size => IO.println s!"terminal size: {size.columns} columns x {size.rows} rows"
  | none => IO.println "terminal size: unavailable"
  if ← stdoutIsTty then
    liveDemo
    liveRegionDemo
  else
    IO.println "live objects: skipped because stdout is not a terminal"
  writeTextLine (Layout.box
    (renderTable [14, 10] [[Text.styled "library" Style.bold, Text.styled "role" Style.bold],
      [Text.plain "termcolor", Text.plain "styles"],
      [Text.plain "layout", Text.plain "width"],
      [Text.plain "widgets", Text.plain "views"],
      [Text.plain "terminal", Text.plain "live IO"]])
    { title := some (Text.plain "stack") })
