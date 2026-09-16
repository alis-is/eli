"""Run with: python3 tools/tests/interpreter_argv0.py /path/to/eli."""
from pathlib import Path
import os
import subprocess
import sys
import tempfile


binary = Path(sys.argv[1]).resolve()
with tempfile.TemporaryDirectory() as directory:
    root = Path(directory)
    env = os.environ.copy()
    env["PATH"] = f"{root}:{env.get('PATH', '')}"
    for name in ("eli space; touch marker", "eli's executable"):
        alias = root / name
        alias.symlink_to(binary)
        env["EXPECTED_INTERPRETER"] = str(alias)
        result = subprocess.run(
            [name, "-e", "assert(INTERPRETER == os.getenv'EXPECTED_INTERPRETER')"],
            executable=binary,
            cwd=root,
            env=env,
            timeout=10,
        )
        assert result.returncode == 0, result.returncode
    assert not (root / "marker").exists()
print("interpreter argv0 quoting regression passed")
