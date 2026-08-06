import re
import subprocess
import sys

allowed = {"propext", "Classical.choice", "Quot.sound"}
native_axioms = {"Lean.ofReduceBool", "Lean.trustCompiler"}
native = {
    "parse_size_rows_columns",
    "parse_size_accepts_mixed_whitespace",
    "parse_size_rejects_missing_dimension",
    "parse_size_rejects_zero",
    "live_region_starts_without_cursor_motion",
    "live_region_clears_removed_lines",
    "live_region_clears_to_empty",
    "live_region_clears_to_empty",
    "live_region_finishes_with_newline",
    "live_progress_uses_widgets",
    "live_indeterminate_progress_uses_widgets",
    "live_spinner_uses_widgets",
    "live_shimmer_uses_widgets",
    "live_status_uses_widgets",
    "live_table_uses_widgets",
    "clear_line_ends_with_carriage_return",
    "live_region_redraws_single_line",
}


def is_native_decide_axiom(decl, axiom):
    """Since Lean v4.29, `native_decide` names its axiom after the declaration it
    closes (`<decl>._native.native_decide.ax_1_1`) instead of reusing
    `Lean.ofReduceBool`. Accept it for the declarations already allowed to use it."""
    return decl in native and "._native.native_decide.ax" in axiom


outputs = []
# One command only. `lake env lean` on a loose file resolved the shared `TermColor.`
# prefix into the termcolor dependency's build directory and could not find this
# package's oleans; the `#print axioms` lines now live in the Properties library, so a
# plain build emits them.
for command in (["lake", "build", "TermColor.Terminal.Properties"],):
    result = subprocess.run(command, text=True, capture_output=True)
    sys.stdout.write(result.stdout)
    sys.stderr.write(result.stderr)
    if result.returncode:
        raise SystemExit(result.returncode)
    outputs.append(result.stdout + result.stderr)

current = None
block = []
failures = []
for line in "\n".join(outputs).splitlines():
    match = re.search(r"'TermColor\.Terminal\.([^']+)' depends on axioms:", line)
    if match:
        current = match.group(1)
        block = [line.split("depends on axioms:", 1)[1]]
        if "]" not in block[0]:
            continue
    elif current and line.strip().startswith("'"):
        current = None
        block = []
    elif current:
        block.append(line)
        if "]" not in line:
            continue
    if current and block and "]" in "".join(block):
        joined = "".join(block)
        axioms = {a.strip() for a in joined[: joined.index("]")].strip(" [").split(",")}
        axioms.discard("")
        permitted = allowed | (native_axioms if current in native else set())
        unexpected = {
            a for a in axioms - permitted if not is_native_decide_axiom(current, a)
        }
        if unexpected:
            failures.append((current, unexpected))
        current = None
        block = []

if failures:
    for name, axioms in failures:
        print(f"unexpected axioms in {name}: {sorted(axioms)}", file=sys.stderr)
    raise SystemExit(1)
