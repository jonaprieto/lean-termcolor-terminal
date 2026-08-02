/-
Copyright (c) 2026 Jonathan Prieto-Cubides. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
-/

import TermColor.Terminal.Properties.Basic

/-!
# Axiom report

Every law in `Basic`, reported at build time. This lives inside the Properties
library rather than in a loose script so that Lake resolves the module with the
package's own module map: `lake env lean` on a file outside any `lean_lib` picked
the `termcolor` dependency's directory for the shared `TermColor.` prefix and failed
to find this package's oleans.
-/

#print axioms TermColor.Terminal.cursor_up_zero
#print axioms TermColor.Terminal.cursor_down_zero
#print axioms TermColor.Terminal.cursor_up_example
#print axioms TermColor.Terminal.cursor_down_example
#print axioms TermColor.Terminal.terminal_control_requires_tty
#print axioms TermColor.Terminal.terminal_control_rejects_dumb
#print axioms TermColor.Terminal.terminal_control_allows_declared_tty
#print axioms TermColor.Terminal.cursor_to_column_is_one_based
#print axioms TermColor.Terminal.clear_line_sequence
#print axioms TermColor.Terminal.screen_and_cursor_sequences
#print axioms TermColor.Terminal.alternate_screen_sequences
#print axioms TermColor.Terminal.hide_show_cursor_sequences
#print axioms TermColor.Terminal.parse_size_rows_columns
#print axioms TermColor.Terminal.parse_size_accepts_mixed_whitespace
#print axioms TermColor.Terminal.parse_size_rejects_missing_dimension
#print axioms TermColor.Terminal.parse_size_rejects_zero
#print axioms TermColor.Terminal.live_region_starts_without_cursor_motion
#print axioms TermColor.Terminal.live_region_clears_removed_lines
#print axioms TermColor.Terminal.live_region_finishes_with_newline
#print axioms TermColor.Terminal.live_region_empty_finish_is_safe
#print axioms TermColor.Terminal.live_progress_uses_widgets
#print axioms TermColor.Terminal.live_indeterminate_progress_uses_widgets
#print axioms TermColor.Terminal.live_spinner_uses_widgets
#print axioms TermColor.Terminal.live_status_uses_widgets
#print axioms TermColor.Terminal.live_table_uses_widgets
