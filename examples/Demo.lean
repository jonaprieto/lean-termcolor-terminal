/-
Copyright (c) 2026 Jonathan Prieto-Cubides. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Jonathan Prieto-Cubides
-/

import TermColor.Terminal

open TermColor
open TermColor.Layout
open TermColor.Terminal
open TermColor.Widgets

private def showSequence (label sequence : String) : IO Unit :=
  IO.println s!"{label}: {repr sequence}"

private def nameConfig : TextInputConfig :=
  { width := 16, maxLength := 16, label := Text.plain "name: " }

private def sliderConfig : SliderConfig :=
  { width := 12, label := Text.plain "volume: " }

private def tuiPreview : Text :=
  let name := updateTextInput nameConfig (.char 'L') {}
  let name := updateTextInput nameConfig (.char 'e') name
  let name := updateTextInput nameConfig (.char 'a') name
  renderTextInput nameConfig name true ++ Text.plain "\n" ++
    renderSlider sliderConfig { value := 7 } ++
    Text.plain "\n" ++
    renderCheckbox { label := Text.plain "enabled" } { checked := true } ++ Text.plain "\n" ++
    renderButton (Text.plain "save") true

private structure TuiState where
  name : TextInputState := {}
  volume : SliderState := { value := 5 }
  enabled : CheckboxState := {}
  focus : Nat := 0

private def tuiView (state : TuiState) : Text :=
  let marker := fun (index : Nat) => Text.plain (if state.focus == index then "> " else "  ")
  marker 0 ++ renderTextInput nameConfig state.name (state.focus == 0) ++ Text.plain "\n" ++
    marker 1 ++ renderSlider sliderConfig state.volume ++ Text.plain "\n" ++
    marker 2 ++ renderCheckbox { label := Text.plain "enabled" } state.enabled ++ Text.plain "\n" ++
    marker 3 ++ renderButton (Text.plain "save") (state.focus == 3) ++ Text.plain "\n" ++
    Text.styled "Tab focus  •  arrows edit  •  Enter save  •  Esc quit" Style.dim

private def applyTuiKey (state : TuiState) (key : Key) : TuiState × Bool :=
  match key with
  | .tab => ({ state with focus := (state.focus + 1) % 4 }, false)
  | .escape => (state, true)
  | _ =>
      match state.focus with
      | 0 => ({ state with name := updateTextInput nameConfig key state.name }, false)
      | 1 => ({ state with volume := updateSlider sliderConfig key state.volume }, false)
      | 2 => ({ state with enabled := updateCheckbox key state.enabled }, false)
      | _ => (state, buttonActivated key)

private def interactiveTui : IO Unit := do
  hideCursor
  try
    withRawInput do
      let mut state : TuiState := {}
      let mut finished := false
      while !finished do
        clearScreen
        writeTextLine
          (Text.styled "interactive TUI demo" Style.bold ++ Text.plain "\n" ++ tuiView state)
        match ← readKey with
        | none => finished := true
        | some key =>
            let (next, activated) := applyTuiKey state key
            state := next
            finished := activated
  finally
    showCursor
    clearScreen

private def liveDemo : IO Unit := do
  IO.println "live progress and spinner:"
  hideCursor
  try
    let mut region := LiveRegion.start
    let width ← terminalWidth
    for current in [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10] do
      let labelStyle := if current == 10 then Style.green else Style.cyan
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
  let outputTty ← stdoutIsTty
  let inputTty ← stdinIsTty
  let inCi := (← IO.getEnv "CI").isSome
  let forcedNonInteractive := (← IO.getEnv "TERMCOLOR_TERMINAL_NONINTERACTIVE").isSome
  if outputTty && inputTty && !inCi && !forcedNonInteractive then
    interactiveTui
  else
    IO.println "static TUI control preview (use a TTY for direct-key interaction):"
    writeTextLine tuiPreview
  if outputTty then
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
