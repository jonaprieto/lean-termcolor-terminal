# Terminal properties

This library is executable formal coverage for `termcolor-terminal`'s pure boundary:

- cursor and visibility sequences have exact ANSI encodings;
- zero-distance cursor movement emits no output;
- terminal-size parsing keeps the `stty` rows/columns convention explicit;
- a `LiveLine` clears only after its first update and finishes with one newline;
- a `LiveRegion` redraws multiple lines and clears lines removed by a later view;
- `LiveProgress`, `LiveSpinner`, `LiveStatus`, and `LiveTable` retain the pure widget views from
  `termcolor-widgets`.

Build it with:

```sh
lake build TerminalProperties
```
