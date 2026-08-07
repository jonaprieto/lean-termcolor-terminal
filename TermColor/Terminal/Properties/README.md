# Terminal properties

This library is executable formal coverage for `termcolor-terminal`'s pure boundary:

- cursor and visibility sequences have exact ANSI encodings;
- zero-distance cursor movement emits no output;
- terminal-size parsing keeps the `stty` rows/columns convention explicit;
- a `LiveRegion` redraws multiple lines and clears lines removed by a later view;
- live text updates cache the terminal width before redraw, keeping wrapped rows aligned;
- pure widget views remain independent from `LiveRegion`, which only owns terminal redraw state.

Build it with:

```sh
lake build TermColor.Terminal.Properties
```
