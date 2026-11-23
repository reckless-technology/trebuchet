#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Jonny Reckless
"""Start each side of a match as fastchess will and prove it searches with the net it was asked to use.

Run by the match workflow (.github/workflows/match.yml) as the `preflight` of pawnstar's shared match-core.yml, in
every chunk, with MATCH_INPUTS naming the unpacked artifact. It reads that artifact's manifest.json, and for each
side starts the engine with the manifest's environment, sends `uci`, the manifest's options, `isready`, a depth-4
search and `quit`, and fails unless a `bestmove` came back and no line says a net was refused. A refused net does not
stop trebuchet playing: the net already loaded keeps playing, so without this check a match whose EvalFile was
refused would be played with the embedded net on that side and report a result for the wrong net.
"""
import json
import os
import subprocess
import sys

REFUSAL_MARKERS = ("keeping the net already loaded", "was refused")


def expand(value, inputs):
    return value.replace("{inputs}", inputs)


def probe(role, side, each_options, inputs):
    environment = dict(os.environ)
    environment.update({key: expand(text, inputs) for key, text in side.get("env", {}).items()})
    options = dict(each_options)
    options.update(side.get("options", {}))
    lines = ["uci"]
    for name, value in options.items():
        lines.append(f"setoption name {name} value {expand(value, inputs)}")
    lines += ["isready", "position startpos", "go depth 4", "quit"]
    command = [expand(side["command"], inputs)] + [expand(argument, inputs) for argument in side.get("args", [])]
    completed = subprocess.run(
        command, input="\n".join(lines) + "\n", capture_output=True, text=True, env=environment, timeout=120
    )
    output = completed.stdout + completed.stderr
    print(f"--- {role}: {' '.join(command)} (exit {completed.returncode})")
    print(output.rstrip())
    problems = []
    if not any(line.startswith("bestmove") for line in output.splitlines()):
        problems.append("no bestmove")
    problems += [f"output says '{marker}'" for marker in REFUSAL_MARKERS if marker in output]
    return problems


def main():
    inputs = os.path.abspath(os.environ.get("MATCH_INPUTS", "."))
    with open(os.path.join(inputs, "manifest.json")) as manifest_file:
        manifest = json.load(manifest_file)
    failures = []
    for role in ("candidate", "baseline"):
        for problem in probe(role, manifest[role], manifest.get("each_options", {}), inputs):
            failures.append(f"{role}: {problem}")
    if failures:
        print("::error::match preflight failed: " + "; ".join(failures))
        return 1
    print("preflight ok: both engines started, searched and kept the net they were given")
    return 0


if __name__ == "__main__":
    sys.exit(main())
