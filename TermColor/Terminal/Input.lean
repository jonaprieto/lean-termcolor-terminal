/-
Copyright (c) 2026 Jonathan Prieto-Cubides. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Jonathan Prieto-Cubides.
-/

import TermColor.Widgets

/-!
# TermColor.Terminal.Input

Pure decoding plus the small raw-input boundary used by interactive TUI applications.
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

private def runStty (command : String) :=
  IO.Process.output { cmd := "sh", args := #["-c", command] }

/-- Run an action with character-at-a-time terminal input, restoring the prior mode afterward. -/
def withRawInput {α : Type} (action : IO α) : IO α := do
  let saved ← runStty "stty -g < /dev/tty"
  if saved.exitCode != 0 then
    throw (IO.userError "could not read terminal settings")
  let configured ← runStty "stty -echo -icanon min 1 time 1 < /dev/tty"
  if configured.exitCode != 0 then
    throw (IO.userError "could not configure raw terminal input")
  try
    action
  finally
    let restore := "stty " ++ saved.stdout.trimAscii.toString ++ " < /dev/tty"
    let _ ← runStty restore

private def readByte : IO (Option UInt8) := do
  let bytes ← (← IO.getStdin).read 1
  pure bytes[0]?

/-- Read one ASCII terminal key, including the common arrow-key escape sequences. -/
def readKey : IO (Option Widgets.Key) := do
  -- ponytail: ASCII byte mapping; add UTF-8 decoding for non-ASCII keyboard input.
  match ← readByte with
  | none => pure none
  | some 27 =>
      match ← readByte with
      | some 91 =>
          match ← readByte with
          | some 65 => pure (some .up)
          | some 66 => pure (some .down)
          | some 67 => pure (some .right)
          | some 68 => pure (some .left)
          | _ => pure (some .escape)
      | _ => pure (some .escape)
  | some 13 | some 10 => pure (some .enter)
  | some 8 | some 127 => pure (some .backspace)
  | some 9 => pure (some .tab)
  | some byte =>
      if byte.toNat < 128 then
        pure (some (.char (Char.ofNat byte.toNat)))
      else
        pure none

end Terminal
end TermColor
