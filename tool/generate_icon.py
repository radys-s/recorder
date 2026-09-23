"""Regenerate Aftermind platform icon rasters from the approved source art.

The source images are kept in ``assets/icon/source``. Windows System.Drawing is
used for high-quality resizing so developers do not need to install Pillow.
Run from the project root on Windows:

    python tool/generate_icon.py
"""
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "tool" / "generate_icon.ps1"


def main() -> None:
    if sys.platform != "win32":
        raise SystemExit("Icon generation currently requires Windows PowerShell and System.Drawing.")
    subprocess.run(
        ["powershell.exe", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(SCRIPT)],
        cwd=ROOT,
        check=True,
    )


if __name__ == "__main__":
    main()
