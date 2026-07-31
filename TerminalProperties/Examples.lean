/-
Copyright (c) 2026 Jonathan Prieto-Cubides. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Jonathan Prieto-Cubides
-/

import TermColorTerminal

namespace TermColor.Terminal

example : cursorUpSequence 1 ++ cursorDownSequence 1 = "\u001b[1A\u001b[1B" := by decide

example : clearLineSequence.endsWith "\r" := by native_decide

example :
    ((LiveLine.start.updateSequence "one").2.updateSequence "two").1 =
      "\u001b[2K\rtwo" := by decide

end TermColor.Terminal
