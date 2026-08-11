/-
Copyright (c) 2026 Jonathan Prieto-Cubides. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Jonathan Prieto-Cubides
-/

import TermColor.Terminal.Buffer
import TermColor.Terminal.UI
import TermColor.Terminal.Input
import Std.Sync.CancellationToken

/-!
# TermColor.Terminal.Runtime

The smallest useful application runtime: typed resize/tick/input events, renderer injection, and
terminal cleanup scoped with `finally`. Applications may use the lower-level pieces when they need
a custom scheduler or background-job protocol.
-/

namespace TermColor
namespace Terminal

open TermColor

/-- A renderer owns its retained output state and terminal writes. -/
structure Renderer (State : Type) where
  start : IO State
  render : Size → State → Rendered → IO State
  finish : State → IO Unit

def lineRenderer (choice : ColorChoice := .auto) : Renderer Screen where
  start := Screen.start
  render := fun _ screen rendered => screen.renderFrame rendered.toFrame choice
  finish := fun screen => do
    let _ ← Screen.finish screen
    pure ()

def bufferRenderer (choice : ColorChoice := .auto) : Renderer BufferScreen where
  start := pure BufferScreen.empty
  render := fun size screen rendered => do
    let buffer := Buffer.fromText size rendered.text
    let (output, next) := screen.diffSequence buffer
    write (← TermColor.render output choice)
    flush
    pure next
  finish := fun screen => do
    if screen.previous.isSome then
      write "\n"
      flush

/-- Scope cursor and alternate-screen state. Both controls restore on failure. -/
def withTerminal {α : Type} (action : IO α) : IO α :=
  withHiddenCursor (withAlternateScreen action)

structure Cancellation where
  token : Std.CancellationToken

namespace Cancellation

def new : IO Cancellation := do
  pure { token := ← Std.CancellationToken.new }

def cancel (cancellation : Cancellation) : IO Unit := cancellation.token.cancel

def isCancelled (cancellation : Cancellation) : IO Bool := cancellation.token.isCancelled

end Cancellation

inductive RuntimeEvent where
  | input (event : Event)
  | resize (size : Size)
  | tick
  deriving BEq, DecidableEq, Repr

structure EventReader where
  result : IO.Ref (Option (Option Event))
  active : IO.Ref Bool
  task : IO.Ref (Option (Task (Except IO.Error Unit)))

namespace EventReader

def new : IO EventReader := do
  pure { result := ← IO.mkRef none, active := ← IO.mkRef false, task := ← IO.mkRef none }

def ensureReading (reader : EventReader) (keepGoing : IO Bool) : IO Unit := do
  unless ← reader.active.get do
    reader.active.set true
    let task ← IO.asTask do
      try
        reader.result.set (some (← readEventWhile keepGoing))
      finally
        reader.active.set false
    reader.task.set (some task)

def take (reader : EventReader) : IO (Option (Option Event)) := do
  let result ← reader.result.get
  if result.isSome then
    reader.result.set none
  pure result

def waitStopped (reader : EventReader) : IO Unit := do
  while ← reader.active.get do
    IO.sleep 1
  match ← reader.task.get with
  | some task => let _ := task.get
  | none => pure ()

end EventReader

structure LoopConfig (Model : Type) where
  initial : Model
  fallbackSize : Size := { columns := Layout.defaultWidth, rows := 24 }
  tickMs : UInt32 := 60
  view : ViewContext → Model → Rendered
  update : RuntimeEvent → Model → Model
  isRunning : Model → Bool := fun _ => true
  mouse : Bool := false

private def currentSize (fallback : Size) : IO Size := do
  pure ((← terminalSize).getD fallback)

private def renderContext (size : Size) : ViewContext :=
  { size, area := { top := 1, left := 1, width := size.columns, height := size.rows } }

/-- Run a small model/view loop with injectable renderer and guaranteed terminal cleanup. -/
def run {Model State : Type} (renderer : Renderer State) (config : LoopConfig Model) : IO Unit := do
  let cancellation ← Cancellation.new
  let reader ← EventReader.new
  let modelRef ← IO.mkRef config.initial
  let sizeRef ← IO.mkRef (← currentSize config.fallbackSize)
  let outputRef ← IO.mkRef (← renderer.start)
  try
    withTerminal do
      try
        if config.mouse then
          withMouseCapture do
            withRawInput do
              while config.isRunning (← modelRef.get) && !(← cancellation.isCancelled) do
                reader.ensureReading (do return !(← cancellation.isCancelled))
                let output ← outputRef.get
                let model ← modelRef.get
                let size ← sizeRef.get
                outputRef.set
                  (← renderer.render size output (config.view (renderContext size) model))
                IO.sleep config.tickMs
                match ← reader.take with
                | some none => cancellation.cancel
                | some (some event) => modelRef.set (config.update (.input event) model)
                | none =>
                    let nextSize ← currentSize config.fallbackSize
                    if nextSize != size then
                      sizeRef.set nextSize
                      modelRef.set (config.update (.resize nextSize) model)
                    else
                      modelRef.set (config.update .tick model)
        else
          withRawInput do
            while config.isRunning (← modelRef.get) && !(← cancellation.isCancelled) do
              reader.ensureReading (do return !(← cancellation.isCancelled))
              let output ← outputRef.get
              let model ← modelRef.get
              let size ← sizeRef.get
              outputRef.set (← renderer.render size output (config.view (renderContext size) model))
              IO.sleep config.tickMs
              match ← reader.take with
              | some none => cancellation.cancel
              | some (some event) => modelRef.set (config.update (.input event) model)
              | none =>
                  let nextSize ← currentSize config.fallbackSize
                  if nextSize != size then
                    sizeRef.set nextSize
                    modelRef.set (config.update (.resize nextSize) model)
                  else
                    modelRef.set (config.update .tick model)
      finally
        cancellation.cancel
        reader.waitStopped
        renderer.finish (← outputRef.get)
  finally
    cancellation.cancel
    reader.waitStopped

end Terminal
end TermColor
