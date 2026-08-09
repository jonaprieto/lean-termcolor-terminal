/-
Copyright (c) 2026 Jonathan Prieto-Cubides. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Jonathan Prieto-Cubides
-/

import TermColor.Terminal.Input

/-!
# TermColor.Terminal.UI

Small typed composition primitives for terminal applications. Views stay pure; the terminal
runtime owns IO, while applications own model state and message handling.
-/

namespace TermColor
namespace Terminal

open Layout

/-- A one-based rectangle in terminal coordinates. -/
structure Rect where
  top : Nat := 1
  left : Nat := 1
  width : Nat := 0
  height : Nat := 0
  deriving BEq, DecidableEq, Repr, Inhabited

namespace Rect

def right (rect : Rect) : Nat := rect.left + rect.width - 1

def bottom (rect : Rect) : Nat := rect.top + rect.height - 1

def move (rect : Rect) (top left : Nat) : Rect := { rect with top, left }

def inset (rect : Rect) (rows columns : Nat) : Rect :=
  { top := rect.top + rows
    left := rect.left + columns
    width := rect.width - 2 * columns
    height := rect.height - 2 * rows }

end Rect

/-- Pure information supplied to every view. -/
structure ViewContext where
  area : Rect := {}
  size : Size := { columns := 80, rows := 24 }
  deriving BEq, DecidableEq, Repr, Inhabited

/-- The pure result of rendering one component. -/
structure Rendered where
  text : Text := Text.empty
  hitRegions : List HitRegion := []
  focusables : List String := []
  focus : Option String := none
  deriving BEq, DecidableEq, Repr, Inhabited

namespace Rendered

def width (rendered : Rendered) : Nat := rendered.text.width

def height (rendered : Rendered) : Nat := rendered.text.height

def toFrame (rendered : Rendered) : Frame :=
  { text := rendered.text, hitRegions := rendered.hitRegions, focusables := rendered.focusables
    focus := rendered.focus }

def fromFrame (frame : Frame) : Rendered :=
  { text := frame.text, hitRegions := frame.hitRegions, focusables := frame.focusables
    focus := frame.focus }

def withPrefix (name : String) (rendered : Rendered) : Rendered :=
  if name.isEmpty then rendered
  else
    { rendered with
      hitRegions := rendered.hitRegions.map fun region =>
        { region with id := name ++ "/" ++ region.id }
      focusables := rendered.focusables.map (fun id => name ++ "/" ++ id)
      focus := rendered.focus.map (fun id => name ++ "/" ++ id) }

private def verticalLines (gap : Nat) : List Text → List Text
  | [] => []
  | first :: rest => first :: rest.flatMap fun item => List.replicate gap Text.empty ++ [item]

def vertical (gap : Nat) (items : List Rendered) : Rendered :=
  { text := Layout.joinLines (verticalLines gap (items.map (·.text)))
    hitRegions := items.flatMap (·.hitRegions)
    focusables := items.flatMap (·.focusables)
    focus := items.findSome? (·.focus) }

def horizontal (gap : Nat) (items : List Rendered) : Rendered :=
  let widths := items.map width
  { text := Layout.columns widths gap (items.map (·.text))
    hitRegions := items.flatMap (·.hitRegions)
    focusables := items.flatMap (·.focusables)
    focus := items.findSome? (·.focus) }

end Rendered

/-- Ordered focus state for a composed rendered tree. -/
structure FocusRing where
  ids : List String := []
  current : Nat := 0
  deriving BEq, DecidableEq, Repr, Inhabited

namespace FocusRing

private def indexOf? (id : String) : List String → Option Nat
  | [] => none
  | candidate :: rest =>
      if candidate == id then some 0 else (indexOf? id rest).map (· + 1)

def fromRendered (rendered : Rendered) : FocusRing :=
  { ids := rendered.focusables
    current := rendered.focus.bind (fun id => indexOf? id rendered.focusables) |>.getD 0 }

def currentId (ring : FocusRing) : Option String := ring.ids[ring.current]?

def move (key : Widgets.Key) (ring : FocusRing) : FocusRing :=
  { ring with current := moveFocus ring.ids.length ring.current key }

def focus (id : String) (ring : FocusRing) : FocusRing :=
  match indexOf? id ring.ids with
  | some current => { ring with current }
  | none => ring

end FocusRing

/-- The component id receiving a terminal event after hit-testing/focus selection. -/
def target (rendered : Rendered) (ring : FocusRing) : Event → Option String
  | .key _ => ring.currentId
  | .mouse event => hitTest rendered.toFrame event

/-- Width allocation used by row composition. -/
inductive Constraint where
  | fixed (width : Nat)
  | percent (value : Nat)
  | fill
  deriving BEq, DecidableEq, Repr, Inhabited

def resolveConstraints (total gap : Nat) (constraints : List Constraint) : List Nat :=
  let available := total - gap * (constraints.length - 1)
  let fixed := constraints.foldl (fun sum constraint =>
    match constraint with
    | .fixed width => sum + width
    | _ => sum) 0
  let percentages := constraints.foldl (fun sum constraint =>
    match constraint with
    | .percent value => sum + available * min 100 value / 100
    | _ => sum) 0
  let remaining := available - min available (fixed + percentages)
  let fills := constraints.countP (· == Constraint.fill)
  let fillWidth := if fills == 0 then 0 else remaining / fills
  constraints.map fun constraint =>
    match constraint with
    | .fixed width => width
    | .percent value => available * min 100 value / 100
    | .fill => fillWidth

/-- A pure view. The runtime decides how the resulting frame reaches the terminal. -/
structure View where
  render : ViewContext → Rendered

namespace View

def text (value : Text) : View := { render := fun _ => { text := value } }

def frame (value : Frame) : View := { render := fun _ => Rendered.fromFrame value }

def column (gap : Nat) (children : List View) : View :=
  { render := fun context =>
      let rec go (offset : Nat) : List View → List Rendered
        | [] => []
        | child :: rest =>
            let childContext := { context with
              area := { context.area with top := context.area.top + offset } }
            let rendered := child.render childContext
            rendered :: go (offset + rendered.height + gap) rest
      Rendered.vertical gap (go 0 children) }

def rowWith (constraints : List Constraint) (gap : Nat) (children : List View) : View :=
  { render := fun context =>
      let constraints :=
        (constraints ++ List.replicate (children.length - constraints.length) Constraint.fill).take
          children.length
      let widths := resolveConstraints context.area.width gap constraints
      let rec go (offset : Nat) : List View → List Nat → List Rendered
        | [], _ => []
        | _, [] => []
        | child :: rest, width :: restWidths =>
            let childContext := { context with
              area := { context.area with left := context.area.left + offset, width } }
            let rendered := child.render childContext
            let rendered := { rendered with
              text := Layout.padRight width (Layout.truncate width rendered.text) }
            rendered :: go (offset + width + gap) rest restWidths
      Rendered.horizontal gap (go 0 children widths) }

def row (gap : Nat) (children : List View) : View :=
  rowWith (List.replicate children.length .fill) gap children

def panel (config : BoxConfig) (child : View) : View :=
  { render := fun context =>
      let inner := context.area.inset 1 config.padding
      let rendered := child.render { context with area := inner }
      let boxed := Layout.box rendered.text
        { config with maxWidth := some context.area.width }
      { rendered with text := boxed } }

def withPrefix (name : String) (child : View) : View :=
  { render := fun context => Rendered.withPrefix name (child.render context) }

end View

/-- A command produced by a component update. Effects remain explicit and typed. -/
inductive Command (Msg : Type) where
  | none
  | send (message : Msg)
  | batch (commands : List (Command Msg))
  | task (work : IO Msg)

namespace Command

def map {α β : Type} (convert : α → β) : Command α → Command β
  | .none => .none
  | .send message => .send (convert message)
  | .batch commands => .batch (commands.map (map convert))
  | .task work => .task (do return convert (← work))

/-- Execute a command tree with a caller-owned message sink. -/
def run {Msg : Type} (send : Msg → IO Unit) (command : Command Msg) : IO Unit := do
  let mut pending := [command]
  while !pending.isEmpty do
    match pending with
    | [] => pure ()
    | command :: rest =>
        match command with
        | .none => pending := rest
        | .send message =>
            send message
            pending := rest
        | .batch commands =>
            -- ponytail: list concatenation keeps the interpreter small; flatten only if profiling
            -- shows deeply nested command batches in a real application.
            pending := commands ++ rest
        | .task work =>
            send (← work)
            pending := rest

end Command

/-- Typed state/update/view contract for reusable application components. -/
structure Component (Model Msg : Type) where
  view : ViewContext → Model → Rendered
  update : Msg → Model → Model × List (Command Msg)

namespace Component

def mapMsg {Model ChildMsg ParentMsg : Type}
    (inject : ChildMsg → ParentMsg) (project : ParentMsg → Option ChildMsg)
    (component : Component Model ChildMsg) : Component Model ParentMsg :=
  { view := component.view
    update := fun message model =>
      match project message with
      | none => (model, [])
      | some childMessage =>
          let (model, commands) := component.update childMessage model
          (model, commands.map (Command.map inject)) }

end Component

end Terminal
end TermColor
