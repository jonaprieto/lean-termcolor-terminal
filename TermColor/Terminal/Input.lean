/-
Copyright (c) 2026 Jonathan Prieto-Cubides. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Jonathan Prieto-Cubides.
-/

import TermColor.Terminal.Basic

/-!
# TermColor.Terminal.Input

Pure decoding plus the small raw-input boundary used by interactive TUI applications.
-/

namespace TermColor
namespace Terminal

inductive MouseButton where
  | left
  | middle
  | right
  | none
  | other (value : Nat)
  deriving BEq, DecidableEq, Repr

inductive MouseAction where
  | press
  | release
  | drag
  | scrollUp
  | scrollDown
  deriving BEq, DecidableEq, Repr

structure MouseModifiers where
  shift : Bool := false
  ctrl : Bool := false
  alt : Bool := false
  deriving BEq, DecidableEq, Repr

structure MouseEvent where
  button : MouseButton
  action : MouseAction
  column : Nat
  row : Nat
  modifiers : MouseModifiers := {}
  deriving BEq, DecidableEq, Repr

inductive Event where
  | key (value : Widgets.Key)
  | mouse (value : MouseEvent)
  deriving BEq, DecidableEq, Repr

private def controlKey (value : Nat) : Option Widgets.Key :=
  if value == 0 then some (.ctrl '@')
  else if value ≤ 26 then some (.ctrl (Char.ofNat (value + 96)))
  else if value < 32 then some (.ctrl (Char.ofNat (value + 64)))
  else none

/-- Decode one complete terminal key sequence. -/
def parseKey (input : String) : Option Widgets.Key :=
  match input with
  | "\u001b[A" => some .up
  | "\u001b[B" => some .down
  | "\u001b[C" => some .right
  | "\u001b[D" => some .left
  | "\u001b[H" | "\u001b[1~" => some .home
  | "\u001b[F" | "\u001b[4~" => some .end
  | "\u001b[5~" => some .pageUp
  | "\u001b[6~" => some .pageDown
  | "\u001b[Z" => some .shiftTab
  | "\u001b[1;2A" | "\u001b[1;5A" => some .up
  | "\u001b[1;2B" | "\u001b[1;5B" => some .down
  | "\u001b[1;2C" | "\u001b[1;5C" => some .right
  | "\u001b[1;2D" | "\u001b[1;5D" => some .left
  | "\r" | "\n" => some .enter
  | "\u0008" | "\u007f" => some .backspace
  | "\t" => some .tab
  | "\u001b" => some .escape
  | _ =>
      match input.toList with
      | [character] => controlKey character.toNat |>.orElse (fun _ => some (.char character))
      | _ => none

private def parseMouseButton (code : Nat) : MouseButton :=
  match code with
  | 0 => .left
  | 1 => .middle
  | 2 => .right
  | value => .other value

/-- Decode an SGR (1006) mouse sequence. Coordinates are one-based, like the protocol. -/
def parseMouseEvent (input : String) : Option MouseEvent := do
  let marker := "\u001b[<".toList
  let chars := input.toList
  if !marker.isPrefixOf chars then none else
    let payload := chars.drop marker.length
    let (terminator, body) ← match payload.reverse with
      | terminator :: rest => some (terminator, rest.reverse)
      | [] => none
    if terminator != 'M' && terminator != 'm' then none else
      let parts := (String.ofList body).splitOn ";"
      let [codeText, columnText, rowText] := parts | none
      let code ← codeText.toNat?
      let column ← columnText.toNat?
      let row ← rowText.toNat?
      if column == 0 || row == 0 then none else
        let wheel := code / 64 > 0
        let dragging := code / 32 % 2 == 1
        let buttonCode := code % 4
        let modifiers : MouseModifiers := {
          shift := code / 4 % 2 == 1
          alt := code / 8 % 2 == 1
          ctrl := code / 16 % 2 == 1
        }
        let action := if wheel then
            if buttonCode == 0 then MouseAction.scrollUp else MouseAction.scrollDown
          else if terminator == 'm' then .release
          else if dragging then .drag
          else .press
        pure {
          button := if wheel then .none else parseMouseButton buttonCode
          action
          column
          row
          modifiers
        }

/-- Decode either a complete key sequence or a complete SGR mouse event. -/
def parseEvent (input : String) : Option Event :=
  match parseMouseEvent input with
  | some event => some (.mouse event)
  | none => match parseKey input with
    | some key => some (.key key)
    | none => none

/-- Return the first hit region for a left-button press; releases and wheels are ignored. -/
def hitTest (frame : Frame) (event : MouseEvent) : Option String :=
  if event.action != .press || event.button != .left then none
  else frame.hitRegions.find? (fun region => region.contains event.row event.column) |>.map (·.id)

/-- Hit-test a mouse event against the frame currently owned by a screen. -/
def Screen.hitTest (screen : Screen) (event : MouseEvent) : Option String :=
  TermColor.Terminal.hitTest screen.frame event

/-- Move through an ordered set of focus slots, wrapping at either end. -/
def moveFocus (count current : Nat) (key : Widgets.Key) : Nat :=
  if count == 0 then 0 else
    match key with
    | .tab | .down | .right | .pageDown => (current + 1) % count
    | .shiftTab | .up | .left | .pageUp => (current + count - 1) % count
    | _ => min current (count - 1)

private def runStty (command : String) :=
  IO.Process.output { cmd := "sh", args := #["-c", command] }

/-- Run an action with character-at-a-time terminal input, restoring the prior mode afterward. -/
def withRawInput {α : Type} (action : IO α) : IO α := do
  let saved ← runStty "stty -g < /dev/tty"
  if saved.exitCode != 0 then
    throw (IO.userError "could not read terminal settings")
  let configured ← runStty "stty -echo -icanon min 0 time 1 < /dev/tty"
  if configured.exitCode != 0 then
    throw (IO.userError "could not configure raw terminal input")
  try
    action
  finally
    let restore := "stty " ++ saved.stdout.trimAscii.toString ++ " < /dev/tty"
    let _ ← runStty restore

private inductive ByteRead where
  | byte (value : UInt8)
  | timeout
  | eof

private def readByte : IO ByteRead := do
  let stdin ← IO.getStdin
  let bytes ← stdin.read 1
  match bytes[0]? with
  | some byte => pure (.byte byte)
  | none => if ← stdin.isTty then pure .timeout else pure .eof

private def readCsi (input : String) : IO String := do
  let rec go (input : String) (fuel : Nat) : IO String := do
    match fuel with
    | 0 => pure input
    | fuel + 1 =>
        match ← readByte with
        | .byte byte =>
            let input := input.push (Char.ofNat byte.toNat)
            if 0x40 ≤ byte.toNat && byte.toNat ≤ 0x7e then pure input
            else go input fuel
        | .timeout | .eof => pure input
  go input 32

private def readEscapeSequence : IO String := do
  match ← readByte with
  | .byte 91 => readCsi "["
  | .byte byte => pure (String.singleton (Char.ofNat byte.toNat))
  | .timeout | .eof => pure ""

/-- Read one complete key or mouse event, waiting through raw-input timeouts. -/
-- partiality: raw terminal timeouts are external; retrying until an event or EOF has no
-- kernel-visible bound.
partial def readEvent : IO (Option Event) := do
  match ← readByte with
  | .timeout => readEvent
  | .eof => pure none
  | .byte 27 =>
      let suffix ← readEscapeSequence
      match parseEvent ("\u001b" ++ suffix) with
      | some event => pure (some event)
      | none => pure (some (.key .escape))
  | .byte byte =>
      match parseEvent (String.singleton (Char.ofNat byte.toNat)) with
      | some event => pure (some event)
      | none => pure none

/-- Read one ASCII terminal key, including the common arrow-key escape sequences. -/
def readKey : IO (Option Widgets.Key) := do
  match ← readEvent with
  | some (.key key) => pure (some key)
  | _ => pure none

end Terminal
end TermColor
