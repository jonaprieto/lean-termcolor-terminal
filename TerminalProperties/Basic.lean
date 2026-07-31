/-
Copyright (c) 2026 Jonathan Prieto-Cubides. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Jonathan Prieto-Cubides
-/

import TermColorTerminal

namespace TermColor
namespace Terminal

theorem cursor_up_zero : cursorUpSequence 0 = "" := by decide

theorem cursor_down_zero : cursorDownSequence 0 = "" := by decide

theorem cursor_up_example : cursorUpSequence 2 = "\u001b[2A" := by decide

theorem cursor_down_example : cursorDownSequence 3 = "\u001b[3B" := by decide

theorem clear_line_sequence : clearLineSequence = "\u001b[2K\r" := by decide

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

theorem live_line_starts_without_clear :
    (LiveLine.start.updateSequence "ready").1 = "ready" := by decide

theorem live_line_clears_before_second_update :
    let state := (LiveLine.start.updateSequence "first").2
    (state.updateSequence "second").1 = clearLineSequence ++ "second" := by decide

theorem live_line_finishes_with_newline :
    let state := (LiveLine.start.updateSequence "ready").2
    (state.finishSequence).1 = "\n" := by decide

theorem idle_live_line_finishes_without_output :
    LiveLine.start.finishSequence.1 = "" := by decide

end Terminal
end TermColor
