/-
Copyright (c) 2026 Jonathan Prieto-Cubides. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Jonathan Prieto-Cubides
-/

import TermColorTerminal.Basic

/-!
# termcolor-terminal

Terminal control sequences and small IO helpers for `termcolor`. Pure rendering stays in
`TermColor`; this module is the boundary for cursor control, flushing, live lines, and terminal
size queries.
-/
