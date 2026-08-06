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
