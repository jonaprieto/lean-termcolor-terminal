import Lake
open Lake DSL

package «termcolor-terminal» where
  version := v!"0.1.3"
  leanOptions := #[⟨`autoImplicit, false⟩, ⟨`relaxedAutoImplicit, false⟩]

require «termcolor» from git
  "https://github.com/jonaprieto/lean-termcolor.git" @ "f0c0cef"

require «termcolor-layout» from git
  "https://github.com/jonaprieto/lean-termcolor-layout.git"
  @ "3b99871"

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
