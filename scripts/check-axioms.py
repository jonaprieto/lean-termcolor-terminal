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
    "live_status_uses_widgets",
    "live_table_uses_widgets",
    "clear_line_ends_with_carriage_return",
    "live_region_redraws_single_line",
}

outputs = []
for command in (
    ["lake", "build", "TermColor.Terminal.Properties"],
    ["lake", "env", "lean", "scripts/check-axioms.lean"],
):
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
        axioms = set(re.findall(r"[A-Za-z][A-Za-z0-9.]*", "".join(block)))
        permitted = allowed | (native_axioms if current in native else set())
        unexpected = axioms - permitted
        if unexpected:
            failures.append((current, unexpected))
        current = None
        block = []

if failures:
    for name, axioms in failures:
        print(f"unexpected axioms in {name}: {sorted(axioms)}", file=sys.stderr)
    raise SystemExit(1)
