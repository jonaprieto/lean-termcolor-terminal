import Lake
open Lake DSL

package «termcolor-terminal» where
  version := v!"0.1.0"
  leanOptions := #[⟨`autoImplicit, false⟩, ⟨`relaxedAutoImplicit, false⟩]

meta if get_config? env = some "dev" then
  require «doc-gen4» from git
    "https://github.com/leanprover/doc-gen4" @ "a41d5ebebfa77afe737fec8de8ad03fc8b08fdff"

require «termcolor» from git
  "https://github.com/jonaprieto/lean-termcolor.git" @ "cad33339fb9e64e251840b8ad4c1a2ba4306b598"

require «termcolor-layout» from git
  "https://github.com/jonaprieto/lean-termcolor-layout.git"
  @ "6cb5303f5ab596e6d9e8801076469c0848ddefd3"

require «termcolor-widgets» from git
  "https://github.com/jonaprieto/lean-termcolor-widgets.git"
  @ "a0330d51b3ec3fc814e8c933fc53313a78e73724"

@[default_target]
lean_lib «TermColorTerminal» where
  globs := #[.andSubmodules `TermColorTerminal]

lean_lib «TerminalProperties» where
  globs := #[.andSubmodules `TerminalProperties]

lean_exe «demo» where
  root := `Demo
  srcDir := "examples"
