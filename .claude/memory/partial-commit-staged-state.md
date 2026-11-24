---
name: partial-commit-staged-state
description: When excluding files from a commit, verify the COMMITTED state builds — not the working tree
metadata:
  type: feedback
---

The rule (when a commit leaves files out, verify the committed tree builds, not the working tree; arm a CI watcher for
every push) is in `reckless-working-practice`'s `references/tooling-gotchas.md`, "A commit that leaves files out can be
built from a tree that is not the committed one", which also carries this incident.

Specific to Trebuchet: the experiment was uncommitted in `search.c` during an SPRT, and the `ln_tables.inc` include-path
move touched the same file (five red CI runs, 2026-07-26).
