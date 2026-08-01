/-
Copyright (c) 2026 Jonathan Prieto-Cubides. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Jonathan Prieto-Cubides
-/

import TermColor.Terminal

/-!
# TermColor.Terminal.Properties.Examples: concrete terminal laws
-/

namespace TermColor.Terminal

theorem cursor_sequences_compose :
    cursorUpSequence 1 ++ cursorDownSequence 1 = "\u001b[1A\u001b[1B" := by decide

theorem clear_line_ends_with_carriage_return : clearLineSequence.endsWith "\r" := by native_decide

theorem live_region_redraws_single_line :
    ((LiveRegion.start.updateSequence "one").2.updateSequence "two").1 =
      "\r\u001b[2K\rtwo" := by
  -- native_decide: private string helpers do not reduce through this module boundary.
  native_decide

end TermColor.Terminal

#print axioms TermColor.Terminal.cursor_sequences_compose
#print axioms TermColor.Terminal.clear_line_ends_with_carriage_return
#print axioms TermColor.Terminal.live_region_redraws_single_line
