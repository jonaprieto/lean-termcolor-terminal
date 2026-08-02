/-
Copyright (c) 2026 Jonathan Prieto-Cubides. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Jonathan Prieto-Cubides.
-/

import TermColor.Widgets

/-!
# TermColor.Terminal.Input

Pure decoding for the key sequences used by the first TUI controls. Reading bytes and putting the
terminal in raw mode remain IO policy owned by the application.
-/

namespace TermColor
namespace Terminal

/-- Decode one complete terminal key sequence. -/
def parseKey (input : String) : Option Widgets.Key :=
  -- ponytail: complete sequences only; add a buffered timeout decoder for incremental raw reads.
  match input with
  | "\u001b[A" => some .up
  | "\u001b[B" => some .down
  | "\u001b[C" => some .right
  | "\u001b[D" => some .left
  | "\r" | "\n" => some .enter
  | "\u0008" | "\u007f" => some .backspace
  | "\t" => some .tab
  | "\u001b" => some .escape
  | _ =>
      match input.toList with
      | [character] => some (.char character)
      | _ => none

/-- Move through an ordered set of focus slots, wrapping at either end. -/
def moveFocus (count current : Nat) (key : Widgets.Key) : Nat :=
  if count == 0 then 0 else
    match key with
    | .tab | .down | .right => (current + 1) % count
    | .up | .left => (current + count - 1) % count
    | _ => min current (count - 1)

end Terminal
end TermColor
