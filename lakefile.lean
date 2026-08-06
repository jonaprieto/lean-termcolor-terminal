import Lake
open Lake DSL

package «termcolor-terminal» where
  version := v!"0.1.8"
  leanOptions := #[⟨`autoImplicit, false⟩, ⟨`relaxedAutoImplicit, false⟩]

require «termcolor» from git
  "https://github.com/jonaprieto/lean-termcolor.git"
  @ "0d5a6ba9ac64912a91fd724eb986a18fc0793b98"

require «termcolor-layout» from git
  "https://github.com/jonaprieto/lean-termcolor-layout.git"
  @ "56dfeb9bfc906c20ba79d2c9b0ab95152d532f0a"

require «termcolor-widgets» from git
  "https://github.com/jonaprieto/lean-termcolor-widgets.git"
  @ "1c01b89920f8f6f60a7e67b8648b24dd8f8dddf1"

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
