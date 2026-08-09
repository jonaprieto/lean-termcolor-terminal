/-
Copyright (c) 2026 Jonathan Prieto-Cubides. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Jonathan Prieto-Cubides
-/

import TermColor.Terminal.Basic

/-!
# TermColor.Terminal.Buffer

Pure cell storage and cell-level diffing. The line renderer remains the default `Screen` backend;
this backend exists for applications that need positioned, partially changing content.
-/

namespace TermColor
namespace Terminal

open Layout

/-- One terminal cell. A continuation cell belongs to the preceding wide glyph. -/
structure Cell where
  glyph : String := " "
  style : Style := {}
  link : Option String := none
  continuation : Bool := false
  deriving BEq, DecidableEq, Repr, Inhabited

def blankCell : Cell := {}

/-- A fixed-size pure terminal surface. Coordinates are zero-based internally. -/
structure Buffer where
  width : Nat
  height : Nat
  cells : Array Cell
  deriving BEq, DecidableEq, Repr

namespace Buffer

def empty (width height : Nat) : Buffer :=
  { width, height, cells := Array.replicate (width * height) blankCell }

private def index (buffer : Buffer) (column row : Nat) : Nat := row * buffer.width + column

def get (buffer : Buffer) (column row : Nat) : Cell :=
  if column < buffer.width && row < buffer.height then
    buffer.cells.getD (index buffer column row) blankCell
  else blankCell

def set (buffer : Buffer) (column row : Nat) (cell : Cell) : Buffer :=
  if column < buffer.width && row < buffer.height then
    { buffer with cells := buffer.cells.set! (index buffer column row) cell }
  else buffer

private def clearWideAt (buffer : Buffer) (column row : Nat) : Buffer :=
  let current := buffer.get column row
  let buffer := if current.continuation && column > 0 then
      buffer.set (column - 1) row blankCell
    else buffer
  let buffer := buffer.set column row blankCell
  if (buffer.get (column + 1) row).continuation then
    buffer.set (column + 1) row blankCell
  else buffer

private def appendZeroWidth (buffer : Buffer) (column row : Nat) (character : Char) : Buffer :=
  if column == 0 || row >= buffer.height then buffer
  else
    let previousColumn := if (buffer.get (column - 1) row).continuation && column > 1
      then column - 2 else column - 1
    let previous := buffer.get previousColumn row
    if previous.continuation then buffer
    else buffer.set previousColumn row { previous with glyph := previous.glyph.push character }

private def writeChar (buffer : Buffer) (column row : Nat) (character : Char) (style : Style)
    (link : Option String) : Buffer × Nat × Nat :=
  if character == '\n' then
    (buffer, 0, row + 1)
  else
    let width := Layout.charWidth character
    if width == 0 then
      (appendZeroWidth buffer column row character, column, row)
    else if row < buffer.height && column + width ≤ buffer.width then
      let buffer := clearWideAt buffer column row
      let buffer := if width == 2 then clearWideAt buffer (column + 1) row else buffer
      let buffer := buffer.set column row { glyph := character.toString, style, link }
      let buffer := if width == 2 then
          buffer.set (column + 1) row { glyph := "", style, link, continuation := true }
        else buffer
      (buffer, column + width, row)
    else
      (buffer, column, row)

private def writeChars (buffer : Buffer) (column row : Nat) (style : Style) (link : Option String) :
    List Char → Buffer × Nat × Nat
  | [] => (buffer, column, row)
  | character :: rest =>
      let (buffer, column, row) := writeChar buffer column row character style link
      writeChars buffer column row style link rest

private def writeSegments (buffer : Buffer) (column row : Nat) : List Segment → Buffer × Nat × Nat
  | [] => (buffer, column, row)
  | segment :: rest =>
      let (buffer, column, row) :=
        writeChars buffer column row segment.style segment.link segment.text.toList
      writeSegments buffer column row rest

/-- Write styled text at a zero-based cell coordinate, clipping at the surface boundary. -/
def writeText (buffer : Buffer) (column row : Nat) (text : Text) : Buffer :=
  (writeSegments buffer column row text.segments).1

/-- Render a wrapped text value into a fixed-size surface. -/
def fromText (size : Size) (text : Text) : Buffer :=
  writeText (empty size.columns size.rows) 0 0
    (Layout.wrapLines (max 1 size.columns) text)

def cellText (cell : Cell) : Text :=
  if cell.continuation then Text.empty
  else { segments := [{ text := cell.glyph, style := cell.style, link := cell.link }] }

def rowText (buffer : Buffer) (row : Nat) : Text :=
  Text.concat ((List.range buffer.width).map fun column => cellText (buffer.get column row))

def rowTextRange (buffer : Buffer) (row start finish : Nat) : Text :=
  Text.concat ((List.range (finish + 1 - start)).map fun offset =>
    cellText (buffer.get (start + offset) row))

def toText (buffer : Buffer) : Text :=
  Layout.joinLines ((List.range buffer.height).map (buffer.rowText ·))

end Buffer

private def csi : String := "\u001b["

private def cursorToCellSequence (row column : Nat) : String :=
  csi ++ toString (row + 1) ++ ";" ++ toString (column + 1) ++ "H"

structure BufferScreen where
  previous : Option Buffer := none
  deriving BEq, DecidableEq, Repr, Inhabited

namespace BufferScreen

def empty : BufferScreen := {}

private def rowBounds (old next : Buffer) (row : Nat) : Option (Nat × Nat) :=
  let bounds : Option (Nat × Nat) := (List.range next.width).foldl
    (fun found column =>
      if old.get column row != next.get column row then
        match found with
        | none => some (column, column)
        | some (first, _) => some (first, column)
      else found) none
  match bounds with
  | none => none
  | some (first, last) =>
      let first := if first > 0 &&
          (old.get (first - 1) row).continuation || (next.get (first - 1) row).continuation
        then first - 1 else first
      let last := if last + 1 < next.width &&
          (old.get (last + 1) row).continuation || (next.get (last + 1) row).continuation
        then last + 1 else last
      some (first, last)

private def fullSequence (buffer : Buffer) : Text :=
  Text.concat ((List.range buffer.height).map fun row =>
    Text.plain (cursorToCellSequence row 0) ++ buffer.rowText row)

/-- Pure cell-level output and next state. Initial or resized surfaces redraw fully. -/
def diffSequence (screen : BufferScreen) (next : Buffer) : Text × BufferScreen :=
  match screen.previous with
  | none => (fullSequence next, { previous := some next })
  | some old =>
      if old.width != next.width || old.height != next.height then
        (fullSequence next, { previous := some next })
      else
        let output := (List.range next.height).foldl (fun output row =>
          match rowBounds old next row with
          | none => output
          | some (first, last) =>
              output ++ Text.plain (cursorToCellSequence row first) ++
                next.rowTextRange row first last) Text.empty
        (output, { previous := some next })

end BufferScreen

end Terminal
end TermColor
