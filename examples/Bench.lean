/-
Copyright (c) 2026 Jonathan Prieto-Cubides. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Jonathan Prieto-Cubides
-/

import TermColor.Terminal

open TermColor
open TermColor.Terminal

private def frames : Nat := 2_000
private def repetitions : Nat := 4

private def runBuffer (size : Size) : IO (Nat × Nat) := do
  let start ← IO.monoNanosNow
  let mut screen := BufferScreen.empty
  let mut bytes := 0
  for frame in List.range frames do
    let text := Text.plain s!"frame {frame} · logs {frame % 17}"
    let buffer := Buffer.fromText size text
    let (output, next) := screen.diffSequence buffer
    screen := next
    bytes := bytes + output.plainText.length
  let elapsed := (← IO.monoNanosNow) - start
  pure (elapsed, bytes)

private def runLines : IO (Nat × Nat) := do
  let start ← IO.monoNanosNow
  let mut screen := Screen.empty
  let mut bytes := 0
  for frame in List.range frames do
    let text := s!"frame {frame} · logs {frame % 17}"
    let (output, next) := screen.diffSequence [text]
    screen := next
    bytes := bytes + output.length
  let elapsed := (← IO.monoNanosNow) - start
  pure (elapsed, bytes)

private def summarize (name : String) (run : IO (Nat × Nat)) : IO Unit := do
  let _ ← run
  let mut samples := []
  let mut bytes := 0
  for _ in List.range repetitions do
    let (elapsed, output) ← run
    samples := elapsed / 100_000 :: samples
    bytes := output
  let total := samples.foldl (· + ·) 0
  let best := samples.foldl min (samples.head?.getD 0)
  let average := total / repetitions
  IO.println (s!"{name}: {frames} frames, best {best / 10}.{best % 10} ms, " ++
    s!"avg {average / 10}.{average % 10} ms, {bytes} output chars")

def main : IO Unit := do
  summarize "buffer 80x24" (runBuffer { columns := 80, rows := 24 })
  summarize "buffer 160x50" (runBuffer { columns := 160, rows := 50 })
  summarize "lines" runLines
