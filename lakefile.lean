import Lake
open Lake DSL

package «termcolor-terminal» where
  version := v!"0.1.0"
  leanOptions := #[⟨`autoImplicit, false⟩, ⟨`relaxedAutoImplicit, false⟩]

meta if get_config? env = some "dev" then
  require «doc-gen4» from git
    "https://github.com/leanprover/doc-gen4" @ "a41d5ebebfa77afe737fec8de8ad03fc8b08fdff"

require «termcolor» from git
  "https://github.com/jonaprieto/lean-termcolor.git" @ "117a3570c2f9dea3b3198998e260a3afa9270ea7"

require «termcolor-layout» from git
  "https://github.com/jonaprieto/lean-termcolor-layout.git"
  @ "7e838f6b0903963f2b7de66cf055d8bf89688682"

require «termcolor-widgets» from git
  "https://github.com/jonaprieto/lean-termcolor-widgets.git"
  @ "8ca0eef4ab10e831cbd752db866e6e94400af81d"

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
