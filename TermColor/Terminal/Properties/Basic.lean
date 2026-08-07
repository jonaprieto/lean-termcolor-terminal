/-
Copyright (c) 2026 Jonathan Prieto-Cubides. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Jonathan Prieto-Cubides
-/

import TermColor.Terminal

namespace TermColor
namespace Terminal

theorem cursor_up_zero : cursorUpSequence 0 = "" := by decide

theorem cursor_down_zero : cursorDownSequence 0 = "" := by decide

theorem cursor_up_example : cursorUpSequence 2 = "\u001b[2A" := by decide

theorem cursor_down_example : cursorDownSequence 3 = "\u001b[3B" := by decide

theorem terminal_control_requires_tty : !terminalControlAllowed false none := by decide

theorem terminal_control_rejects_dumb : !terminalControlAllowed true (some "dumb") := by decide

theorem terminal_control_allows_declared_tty :
    terminalControlAllowed true (some "xterm") := by decide

theorem parse_key_sequences :
    parseKey "\u001b[A" = some .up ∧
      parseKey "\u001b[D" = some .left ∧
      parseKey "\r" = some .enter ∧
      parseKey "\u007f" = some .backspace := by
  decide

theorem parse_key_char_and_reject_partial_sequence :
    parseKey "x" = some (.char 'x') ∧ parseKey "\u001b[" = none := by
  decide

theorem parse_key_controls_and_extended_sequences :
    parseKey "\u0004" = some (.ctrl 'd') ∧
      parseKey "\u001b[1~" = some .home ∧
      parseKey "\u001b[6~" = some .pageDown ∧
      parseKey "\u001b[Z" = some .shiftTab := by
  decide

theorem parse_sgr_mouse_event :
    parseMouseEvent "\u001b[<0;12;4M" = some {
      button := .left
      action := .press
      column := 12
      row := 4
      modifiers := {}
    } := by
  native_decide

theorem parse_sgr_mouse_drag_modifiers :
    (parseMouseEvent "\u001b[<52;3;2M").map
      (fun event => (event.action, event.modifiers.ctrl)) =
      some (MouseAction.drag, true) := by
  native_decide

theorem parse_mouse_filters_press_release_and_scroll :
    (parseMouseEvent "\u001b[<0;2;3M").map (·.action) = some .press ∧
      (parseMouseEvent "\u001b[<0;2;3m").map (·.action) = some .release ∧
      (parseMouseEvent "\u001b[<64;2;3M").map (·.action) = some .scrollUp := by
  native_decide

theorem hit_region_contains_inclusive_boundaries :
    let region : HitRegion := { id := "job", top := 2, bottom := 4, left := 3, right := 8 }
    region.contains 2 3 ∧ region.contains 4 8 ∧ !region.contains 1 3 ∧ !region.contains 3 9 := by
  decide

theorem hit_test_accepts_only_left_presses :
    let frame : Frame :=
      { hitRegions := [{ id := "job", top := 2, bottom := 4, left := 3, right := 8 }] }
    hitTest frame { button := .left, action := .press, row := 3, column := 4 } = some "job" ∧
      hitTest frame { button := .left, action := .release, row := 3, column := 4 } = none ∧
      hitTest frame { button := .right, action := .press, row := 3, column := 4 } = none ∧
      hitTest frame { button := .none, action := .scrollUp, row := 3, column := 4 } = none := by
  native_decide

theorem hit_test_uses_first_overlapping_region :
    let frame : Frame :=
      { hitRegions :=
        [{ id := "outer", top := 1, bottom := 5, left := 1, right := 10 },
         { id := "inner", top := 2, bottom := 4, left := 3, right := 8 }] }
    hitTest frame { button := .left, action := .press, row := 3, column := 4 } = some "outer" ∧
      hitTest frame { button := .left, action := .press, row := 8, column := 4 } = none := by
  native_decide

theorem screen_diff_rewrites_changed_lines :
    (Screen.empty.diffSequence ["one", "two"]).1 =
      "\u001b[1;1H\u001b[2K\rone\u001b[2;1H\u001b[2K\rtwo" := by
  native_decide

theorem mouse_capture_sequences_are_scoped :
    mouseCaptureSequence true false = "\u001b[?1000h\u001b[?1006h" ∧
      mouseCaptureSequence false false = "\u001b[?1006l\u001b[?1000l" := by
  decide

theorem focus_wraps :
    moveFocus 3 2 .tab = 0 ∧
      moveFocus 3 0 .left = 2 ∧
      moveFocus 0 4 .tab = 0 := by
  decide

theorem cursor_to_column_is_one_based : cursorToColumnSequence 0 = "\u001b[1G" := by decide

theorem clear_line_sequence : clearLineSequence = "\u001b[2K\r" := by decide

theorem screen_and_cursor_sequences :
    clearScreenSequence = "\u001b[2J\u001b[H" ∧
      saveCursorSequence = "\u001b[s" ∧ restoreCursorSequence = "\u001b[u" := by
  decide

theorem alternate_screen_sequences :
    enterAlternateScreenSequence = "\u001b[?1049h" ∧
      exitAlternateScreenSequence = "\u001b[?1049l" := by decide

theorem hide_show_cursor_sequences :
    hideCursorSequence = "\u001b[?25l" ∧ showCursorSequence = "\u001b[?25h" := by decide

theorem parse_size_rows_columns :
    (parseSize "24 80\n").map (fun size => (size.columns, size.rows)) = some (80, 24) := by
  native_decide

theorem parse_size_accepts_mixed_whitespace :
    (parseSize "\t24  \n80\r").map (fun size => (size.columns, size.rows)) =
      some (80, 24) := by native_decide

theorem parse_size_rejects_missing_dimension : parseSize "80" = none := by native_decide

theorem parse_size_rejects_zero : parseSize "0 80" = none := by native_decide

theorem live_region_starts_without_cursor_motion :
    (LiveRegion.start.updateSequence "first\nsecond").1 =
      "\u001b[2K\rfirst\n\u001b[2K\rsecond" := by
  -- native_decide: private string helpers do not reduce through this module boundary.
  native_decide

theorem live_region_clears_removed_lines :
    let state := (LiveRegion.start.updateSequence "first\nsecond").2
    (state.updateSequence "done").1 =
      "\u001b[1A\r\u001b[2K\rdone\u001b[1B\u001b[2K\r\u001b[1A\r" := by
  -- native_decide: private string helpers do not reduce through this module boundary.
  native_decide

theorem live_region_clears_to_empty :
    let state := (LiveRegion.start.updateSequence "one\ntwo").2
    (state.updateSequence "").1 =
      "\u001b[1A\r\u001b[2K\r\u001b[1B\u001b[2K\r\u001b[1A\r" := by
  -- native_decide: private string helpers do not reduce through this module boundary.
  native_decide

theorem live_region_finishes_with_newline :
    let state := (LiveRegion.start.updateSequence "one\ntwo").2
    state.finishSequence.1 = "\n" := by
  -- native_decide: the private width cache is part of the state update.
  native_decide

theorem live_region_empty_finish_is_safe :
    LiveRegion.start.finishSequence.1 = "" := by decide

theorem live_progress_uses_widgets :
    let live := LiveProgress.start { width := 4 }
    let live := { live with state := { current := 1, total := 2 } }
    live.view.plainText = "[━━──] 50%" := by native_decide

theorem live_indeterminate_progress_uses_widgets :
    let live := LiveIndeterminateProgress.start { width := 8, indeterminateWidth := 3 }
    let live := { live with state := { frame := 2 } }
    live.view.plainText = "[──━━━───]" := by native_decide

theorem live_spinner_uses_widgets :
    let live := LiveSpinner.start { frames := [Text.plain "-", Text.plain "+"] }
    let live := { live with state := { frame := 1 } }
    live.view.plainText = "+" := by native_decide

theorem live_shimmer_uses_widgets :
    let live := LiveShimmer.start (Text.plain "hi") { band := 2 }
    let live := { live with state := { frame := 3 } }
    live.view.plainText = "hi" := by native_decide

theorem live_status_uses_widgets :
    let live := LiveStatus.start .warning
    let live := { live with message := Text.plain "slow" }
    live.view.plainText = "[warn] slow" := by native_decide

theorem live_table_uses_widgets :
    let live := LiveTable.start [5, 5]
    let live := { live with rows := [[Text.plain "name", Text.plain "state"]] }
    live.view.plainText = "name   state" := by native_decide

end Terminal
end TermColor

#print axioms TermColor.Terminal.live_region_clears_to_empty
