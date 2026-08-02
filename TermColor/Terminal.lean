/-
Copyright (c) 2026 Jonathan Prieto-Cubides. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Jonathan Prieto-Cubides
-/

import TermColor.Terminal.Basic
import TermColor.Terminal.Input

/-!
# termcolor-terminal

Terminal control sequences and live IO helpers for the `termcolor` stack. Pure rendering stays in
`TermColor`, `termcolor-layout`, and `termcolor-widgets`; this module is the boundary for cursor
control, flushing, live objects, and terminal-size queries.
-/
