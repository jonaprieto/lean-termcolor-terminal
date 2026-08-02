import Lake
open Lake DSL

package «termcolor-terminal» where
  version := v!"0.1.2"
  leanOptions := #[⟨`autoImplicit, false⟩, ⟨`relaxedAutoImplicit, false⟩]

require «termcolor» from git
  "https://github.com/jonaprieto/lean-termcolor.git" @ "90d49ed"

require «termcolor-layout» from git
  "https://github.com/jonaprieto/lean-termcolor-layout.git"
  @ "8cf89d9"

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
