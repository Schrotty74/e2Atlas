#!/usr/bin/env python3
"""Run a local build command with bounded, portable diagnostic logs."""

import datetime
import os
from pathlib import Path
import re
import subprocess
import sys
import uuid


def portable_text(text, root):
    # Diagnostic paths are observations, never paths used to run the command.
    for original, replacement in sorted(
        [(str(root.resolve()), "."), (str(Path.home()), "<home>")],
        key=lambda pair: len(pair[0]), reverse=True
    ):
        text = text.replace(original, replacement)
    text = re.sub(r"/Users/[^/\s\"']+", "<home>", text)
    text = re.sub(r"/(?:private/)?var/folders/[^\s\"']+", "<temporary>", text)
    return text


def main():
    if len(sys.argv) < 4 or sys.argv[2] != "--":
        raise SystemExit("Usage: run-logged.py Dev|Beta|Final|Tests -- command [arguments]")
    group = sys.argv[1]
    if group not in {"Dev", "Beta", "Final", "Tests"}:
        raise SystemExit("Unknown log category")
    root = Path(__file__).resolve().parent.parent
    directory = root / "Build" / "Logs" / group
    directory.mkdir(parents=True, exist_ok=True)
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    path = directory / f"run-{stamp}-{uuid.uuid4().hex[:8]}.log"
    environment = dict(os.environ, E2ATLAS_LOG_ACTIVE="1")
    with path.open("x", encoding="utf-8") as log:
        log.write(f"Category: {group}\nUTC: {stamp}\nProject paths are relative; home and temporary paths are masked.\n")
        try:
            with subprocess.Popen(sys.argv[3:], env=environment, stdout=subprocess.PIPE,
                                  stderr=subprocess.STDOUT, text=True, errors="replace") as process:
                for line in process.stdout:
                    line = portable_text(line, root)
                    log.write(line)
                    log.flush()
                    print(line, end="", flush=True)
                result = process.wait()
        except OSError as error:
            result = 127
            log.write(portable_text(str(error), root) + "\n")
        log.write(f"\nExit status: {result}\n")
    # Only files owned by this logger are rotated, after the command completes.
    completed = [p for p in sorted(directory.glob("run-*.log"), reverse=True)
                 if "\nExit status: " in p.read_text(encoding="utf-8")[-100:]]
    for old in completed[5:]:
        old.unlink()
    print(f"Log: {path.relative_to(root)}")
    return result if result >= 0 else 128 - result


if __name__ == "__main__":
    sys.exit(main())
