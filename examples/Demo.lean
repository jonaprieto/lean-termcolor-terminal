/-
Copyright (c) 2026 Jonathan Prieto-Cubides. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Jonathan Prieto-Cubides
-/

import TermColor.Terminal
import TermColor.ColorScheme

open TermColor
open TermColor.Layout
open TermColor.Terminal
open TermColor.Widgets
open scoped TermColor.Style

private def demoPalette : ColorScheme := ColorScheme.catppuccin

private def showSequence (label sequence : String) : IO Unit :=
  IO.println s!"{label}: {repr sequence}"

private def nameConfig : TextInputConfig :=
  { width := 16, maxLength := 16
    , label := Text.styled "name: " (Style.fg demoPalette.cyan) }

private def sliderConfig : SliderConfig :=
  { width := 12, label := Text.styled "volume: " (Style.fg demoPalette.blue) }

private structure TuiState where
  tab : Nat := 0
  name : TextInputState := {}
  volume : SliderState := { value := 5 }
  enabled : CheckboxState := {}
  focus : Nat := 0

private def tabLabel (label : String) (color : Color) (selected focused : Bool) : Text :=
  let body := if selected then Text.plain "[" ++ Text.plain label ++ Text.plain "]"
    else Text.plain " " ++ Text.plain label ++ Text.plain " "
  let style := Style.fg color <+> (if selected then Style.bold else Style.empty) <+>
    (if focused then Style.reverse else Style.empty)
  Text.styled (Text.plainText body) style

private def boxesView : Text :=
  let inner := Layout.box (Text.styled "nested content\nwith a title" (Style.fg demoPalette.green))
    { maxWidth := some 22
      , title := some (Text.styled "inner" (Style.bold <+> Style.fg demoPalette.cyan))
      , borderStyle := Style.fg demoPalette.comment }
  let outer := Layout.box inner
    { maxWidth := some 36
      , title := some (Text.styled "nested" (Style.bold <+> Style.fg demoPalette.purple))
      , borderStyle := Style.fg demoPalette.foreground }
  let first := Layout.box (Text.styled "first box" (Style.fg demoPalette.green))
    { maxWidth := some 22
      , title := some (Text.styled "one" (Style.fg demoPalette.cyan))
      , borderStyle := Style.fg demoPalette.comment }
  let second := Layout.box (Text.styled "second box" (Style.fg demoPalette.yellow))
    { maxWidth := some 22
      , title := some (Text.styled "two" (Style.fg demoPalette.cyan))
      , borderStyle := Style.fg demoPalette.comment }
  let stacked := first ++ Text.plain "\n" ++ second
  let side := Layout.box stacked
    { maxWidth := some 28
      , title := some (Text.styled "stacked" (Style.bold <+> Style.fg demoPalette.purple))
      , borderStyle := Style.fg demoPalette.foreground }
  Layout.columns [36, 28] 2 [outer, side]

private def aboutView : Text :=
  Layout.box (Text.styled "Boxes are pure Text.\nTabs are app state." (Style.fg demoPalette.green))
    { maxWidth := some 48
      , title := some (Text.styled "about" (Style.bold <+> Style.fg demoPalette.cyan))
      , borderStyle := Style.fg demoPalette.comment }

private def focusCount (state : TuiState) : Nat :=
  if state.tab == 0 then 5 else 1

private def selectTab (state : TuiState) (tab : Nat) : TuiState :=
  { state with tab := tab % 3, focus := 0 }

private def formView (state : TuiState) : Text :=
  let marker := fun (index : Nat) => Text.plain (if state.focus == index then "> " else "  ")
  marker 1 ++ renderTextInput nameConfig state.name (state.focus == 1) ++ Text.plain "\n" ++
    marker 2 ++ renderSlider sliderConfig state.volume ++ Text.plain "\n" ++
    marker 3 ++
      (renderCheckbox
        { label := Text.styled "enabled" (Style.fg demoPalette.green) } state.enabled) ++
      Text.plain "\n" ++
    marker 4 ++
      (renderButton (Text.styled "save" (Style.fg demoPalette.purple)) (state.focus == 4))

private def tuiView (state : TuiState) (showHelp : Bool := true) : Text :=
  let tabs := (if state.focus == 0 then Text.plain "> " else Text.plain "  ") ++
    tabLabel "Form" demoPalette.cyan (state.tab == 0) (state.focus == 0) ++
    tabLabel "Boxes" demoPalette.purple (state.tab == 1) (state.focus == 0) ++
    tabLabel "About" demoPalette.green (state.tab == 2) (state.focus == 0)
  let page := if state.tab == 0 then formView state
    else if state.tab == 1 then boxesView else aboutView
  let footer := if showHelp then
      Text.plain "\n\n" ++
        Text.styled "Tab focus  •  Left/Right tabs or edit  •  Enter save  •  Esc quit"
          (Style.dim <+> Style.fg demoPalette.comment)
    else Text.empty
  tabs ++ Text.plain "\n" ++ page ++ footer

private def applyControlKey (state : TuiState) (key : Key) : TuiState × Bool :=
  if state.tab != 0 then
    (state, false)
  else
    match state.focus with
    | 1 => ({ state with name := updateTextInput nameConfig key state.name }, false)
    | 2 => ({ state with volume := updateSlider sliderConfig key state.volume }, false)
    | 3 => ({ state with enabled := updateCheckbox key state.enabled }, false)
    | 4 => (state, buttonActivated key)
    | _ => (state, false)

private def applyTuiKey (state : TuiState) (key : Key) : TuiState × Bool :=
  match key with
  | .tab => ({ state with focus := moveFocus (focusCount state) state.focus .tab }, false)
  | .escape => (state, true)
  | .left =>
      if state.focus == 0 then (selectTab state (state.tab + 2), false)
      else applyControlKey state key
  | .right =>
      if state.focus == 0 then (selectTab state (state.tab + 1), false)
      else applyControlKey state key
  | _ => applyControlKey state key

private def interactiveTui : IO Unit := do
  hideCursor
  try
    withRawInput do
      let mut state : TuiState := {}
      let mut finished := false
      while !finished do
        clearScreen
        writeTextLine
          (Text.styled "interactive TUI demo" (Style.bold <+> Style.fg demoPalette.foreground) ++
            Text.plain "\n" ++ tuiView state)
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
    for current in [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10] do
      let width ← terminalWidth
      let labelStyle :=
        if current == 10 then Style.fg demoPalette.green else Style.fg demoPalette.cyan
      let barWidth := max 10 (min 40 (max 1 (width - 20)))
      let progress := progressBar
        { width := barWidth
          , filledStyle := Style.fg demoPalette.blue
          , emptyStyle := Style.dim <+> Style.fg demoPalette.comment
          , percentageStyle := Style.fg demoPalette.foreground }
        { current, total := 10, label := Text.styled "download" labelStyle }
      let spinner := renderSpinner { prefixText := Text.plain "  " }
        { frame := current, label := Text.styled "working" (Style.fg demoPalette.foreground) }
      region ← region.updateText (progress ++ Text.plain "\n" ++ spinner)
      IO.sleep 150
    let _ ← region.finish
    let unknown := LiveIndeterminateProgress.start
      { width := 20, indeterminateWidth := 8
        , filledStyle := Style.fg demoPalette.cyan
        , emptyStyle := Style.dim <+> Style.fg demoPalette.comment }
    let mut unknown := unknown
    for frame in List.range 25 do
      unknown ← unknown.update
        { frame, label := Text.styled "indexing (unknown)" (Style.fg demoPalette.cyan) }
      IO.sleep 150
    let _ ← unknown.finish
    let status := LiveStatus.start
    let status ← status.update .warning
      (Text.styled "using a fallback" (Style.fg demoPalette.yellow))
    IO.sleep 150
    let _ ← status.update .success (Text.styled "ready" (Style.fg demoPalette.green))
    let _ ← status.finish
  finally
    showCursor

private def liveRegionDemo : IO Unit := do
  IO.println "live region:"
  hideCursor
  try
    let table := LiveTable.start [12, 10]
    let table ← table.update
      [[Text.styled "task" (Style.bold <+> Style.fg demoPalette.purple)
        , Text.styled "status" (Style.bold <+> Style.fg demoPalette.purple)],
       [Text.plain "download", Text.styled "running" (Style.fg demoPalette.yellow)]]
    let _ ← table.update
      [[Text.styled "task" (Style.bold <+> Style.fg demoPalette.purple)
        , Text.styled "status" (Style.bold <+> Style.fg demoPalette.purple)],
       [Text.plain "download", Text.styled "done" (Style.fg demoPalette.green)]]
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
  let controlsEnabled ← stdoutSupportsControl
  let inCi := (← IO.getEnv "CI").isSome
  let forcedNonInteractive := (← IO.getEnv "TERMCOLOR_TERMINAL_NONINTERACTIVE").isSome
  let liveEnabled := outputTty && !inCi && !forcedNonInteractive
  if outputTty && inputTty && controlsEnabled && !inCi && !forcedNonInteractive then
    try
      interactiveTui
    catch _ =>
      IO.println "interactive input unavailable; showing static preview"
      writeTextLine (tuiView { tab := 1 } false)
  else
    IO.println "static TUI preview (use a capable TTY for direct-key interaction):"
    writeTextLine (tuiView { tab := 1 } false)
  if liveEnabled then
    liveDemo
    liveRegionDemo
  else
    IO.println "live objects: skipped because stdout is not a terminal"
  writeTextLine (Layout.box
    (renderTable [14, 10]
      [[Text.styled "library" (Style.bold <+> Style.fg demoPalette.purple)
        , Text.styled "role" (Style.bold <+> Style.fg demoPalette.purple)],
      [Text.plain "termcolor", Text.plain "styles"],
      [Text.plain "layout", Text.plain "width"],
      [Text.plain "widgets", Text.plain "views"],
      [Text.plain "terminal", Text.plain "live IO"]])
    { title := some (Text.styled "stack" (Style.bold <+> Style.fg demoPalette.cyan))
      , borderStyle := Style.fg demoPalette.comment })
