import Lake
open Lake DSL

package «termcolor-terminal» where
  version := v!"0.1.4"
  leanOptions := #[⟨`autoImplicit, false⟩, ⟨`relaxedAutoImplicit, false⟩]

require «termcolor» from git
  "https://github.com/jonaprieto/lean-termcolor.git"
  @ "f0c0cef08a9c0c2019929856d48c6ba46458a26f"

require «termcolor-layout» from git
  "https://github.com/jonaprieto/lean-termcolor-layout.git"
  @ "d8c68e5f32ebd21a85c834923c95e113599da7a6"

require «termcolor-widgets» from git
  "https://github.com/jonaprieto/lean-termcolor-widgets.git"
  @ "d7ea881"

@[default_target]
lean_lib «TermColor.Terminal» where
  roots := #[`TermColor.Terminal]
  globs := #[.andSubmodules `TermColor.Terminal]

lean_lib «TermColor.Terminal.Properties» where
  roots := #[`TermColor.Terminal.Properties]
  globs := #[.andSubmodules `TermColor.Terminal.Properties]

lean_exe «demo» where
  root := `Demo
  srcDir := "examples"
