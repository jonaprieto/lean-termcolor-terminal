/-
Copyright (c) 2026 Jonathan Prieto-Cubides. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Jonathan Prieto-Cubides
-/

import TermColorTerminal

open TermColor
open TermColor.Terminal

private def showSequence (label sequence : String) : IO Unit :=
  IO.println s!"{label}: {repr sequence}"

private def liveDemo : IO Unit := do
  IO.println "live line:"
  hideCursor
  let line := LiveLine.start
  let line ← line.update "  downloading 0%"
  let line ← line.update "  downloading 50%"
  let line ← line.update "  downloading 100%"
  let _ ← line.finish
  showCursor

def main : IO Unit := do
  IO.println "termcolor-terminal"
  IO.println "pure control sequences:"
  showSequence "cursor up 2" (cursorUpSequence 2)
  showSequence "cursor down 2" (cursorDownSequence 2)
  showSequence "clear line" clearLineSequence
  showSequence "hide cursor" hideCursorSequence
  showSequence "show cursor" showCursorSequence
  match ← terminalSize with
  | some size => IO.println s!"terminal size: {size.columns} columns x {size.rows} rows"
  | none => IO.println "terminal size: unavailable"
  if ← stdoutIsTty then
    liveDemo
  else
    IO.println "live line: skipped because stdout is not a terminal"
