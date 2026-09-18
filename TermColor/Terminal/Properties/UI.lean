/-
Copyright (c) 2026 Jonathan Prieto-Cubides. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Jonathan Prieto-Cubides
-/

import TermColor.Terminal

/-!
# TermColor.Terminal.Properties.UI

Small executable laws for the composable view and cell renderer contracts.
-/

namespace TermColor
namespace Terminal

theorem ui_column_preserves_order :
    ((View.column 1 [View.text (Text.plain "left"), View.text (Text.plain "right")]).render
      { area := { top := 1, left := 1, width := 20, height := 4 } }).text.plainText =
      "left\n\nright" := by
  native_decide

theorem ui_row_composes_columns :
    ((View.rowWith [.fixed 1, .fixed 1] 1
      [View.text (Text.plain "a"), View.text (Text.plain "b")]).render
      { area := { top := 1, left := 1, width := 20, height := 1 } }).text.plainText =
      "a b" := by
  native_decide

theorem ui_constraints_resolve_fixed_percent_fill :
    resolveConstraints 20 1 [.fixed 3, .fill, .percent 25] = [3, 11, 4] := by
  native_decide

theorem ui_prefix_names_child_targets :
    let rendered := Rendered.withPrefix "pane"
      { hitRegions := [{ id := "button", top := 1, bottom := 1, left := 1, right := 1 }]
        focusables := ["button"], focus := some "button" }
    rendered.hitRegions.map (·.id) = ["pane/button"] ∧
      rendered.focusables = ["pane/button"] ∧ rendered.focus = some "pane/button" := by
  native_decide

theorem focus_ring_traverses_composed_children :
    let rendered : Rendered :=
      { focusables := ["jobs/one", "jobs/two"], focus := some "jobs/one" }
    let ring := FocusRing.fromRendered rendered
    ring.currentId = some "jobs/one" ∧
      (FocusRing.move .tab ring).currentId = some "jobs/two" ∧
      (FocusRing.move .shiftTab ring).currentId = some "jobs/two" := by
  native_decide

theorem target_routes_focus_and_mouse_events :
    let rendered : Rendered :=
      { hitRegions := [{ id := "jobs/one", top := 2, bottom := 2, left := 3, right := 6 }]
        focusables := ["jobs/one"], focus := some "jobs/one" }
    let ring := FocusRing.fromRendered rendered
    target rendered ring (.key .enter) = some "jobs/one" ∧
      target rendered ring (.mouse
        { button := .left, action := .press, column := 4, row := 2 }) = some "jobs/one" := by
  native_decide

theorem component_maps_parent_messages :
    let child : Component Nat Nat :=
      { view := fun _ model => { text := Text.plain (toString model) }
        update := fun message model => (model + message, []) }
    let parent := Component.mapMsg (fun message => message + 10)
      (fun message => if message ≥ 10 then some (message - 10) else none) child
    (parent.update 12 3).1 = 5 := by
  native_decide

theorem buffer_round_trips_fixed_surface :
    (Buffer.fromText { columns := 4, rows := 2 } (Text.plain "ab\nc")).toText.plainText =
      "ab  \nc   " := by
  native_decide

theorem buffer_initial_draw_is_positioned :
    (BufferScreen.empty.diffSequence
      (Buffer.fromText { columns := 3, rows := 1 } (Text.plain "abc"))).1.plainText =
      "\u001b[1;1Habc" := by
  native_decide

theorem buffer_unchanged_frame_is_empty :
    let buffer := Buffer.fromText { columns := 3, rows := 1 } (Text.plain "abc")
    let screen := (BufferScreen.empty.diffSequence buffer).2
    (screen.diffSequence buffer).1 = Text.empty := by
  native_decide

theorem buffer_diff_starts_at_changed_cell :
    let old := Buffer.fromText { columns := 3, rows := 1 } (Text.plain "abc")
    let next := Buffer.fromText { columns := 3, rows := 1 } (Text.plain "axc")
    let screen := (BufferScreen.empty.diffSequence old).2
    (screen.diffSequence next).1.plainText = "\u001b[1;2Hx" := by
  native_decide

theorem buffer_marks_wide_glyph_continuation :
    let buffer := Buffer.fromText { columns := 4, rows := 1 } (Text.plain "界a")
    (buffer.get 0 0).glyph = "界" ∧ (buffer.get 1 0).continuation := by
  native_decide

theorem buffer_preserves_style_and_link_metadata :
    let text := Text.hyperlink "https://example.test" (Text.styled "x" Style.bold)
    let cell := (Buffer.fromText { columns := 1, rows := 1 } text).get 0 0
    cell.style = Style.bold ∧ cell.link = some "https://example.test" := by
  native_decide

theorem buffer_combining_marks_do_not_consume_cells :
    let buffer := Buffer.fromText { columns := 3, rows := 1 } (Text.plain "áb")
    (buffer.get 0 0).glyph = "á" ∧ (buffer.get 1 0).glyph = "b" := by
  native_decide

theorem buffer_overwrite_clears_wide_continuation :
    let wide := Buffer.writeText (Buffer.empty 3 1) 0 0 (Text.plain "界")
    let next := Buffer.writeText wide 0 0 (Text.plain "a")
    (next.get 0 0).glyph = "a" ∧ next.get 1 0 = blankCell := by
  native_decide

end Terminal
end TermColor
