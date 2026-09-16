"""Run with python3 tools/tests/watchdog.py; exercise the macOS fallback."""
from pathlib import Path
import subprocess


source = Path("tools/test.sh").read_text()
function = source[source.index("run_suite() {"):source.index("\ntest_build() {")]
function = function.replace("command -v timeout >/dev/null 2>&1", "false")
function = function.replace('"$_waited" -ge 900', '"$_waited" -ge 1')
function = function.replace("sleep 10", "sleep 1")
for command, expected in [
    ("exit 0", 0),
    ("exit 7", 7),
    ("trap 'exit 0' TERM; while :; do sleep 1; done", 124),
    ("trap '' TERM; while :; do sleep 1; done", 124),
]:
    result = subprocess.run(
        ["sh", "-c", function + '\nrun_suite sh -c "$1"', "watchdog", command],
        timeout=10,
    )
    assert result.returncode == expected, (command, result.returncode, expected)
print("watchdog regressions passed")
