---
name: sprt-progress-reporting
description: "Jonny wants periodic interim progress reports from long SPRT runs, not silence-until-verdict"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 221925ef-3c7d-4275-96ac-0cd7362cb511
  modified: 2026-07-31T06:04:48.722Z
---

The method (report progress while an SPRT or SPSA run is going, keep the whole fastchess log, attach a Monitor on the
`Games:` lines, pin Threads, Hash and OwnBook on both engines and verify the pins from `/proc/<pid>/cmdline`) is in the
`reckless-chess-engines` skill, "Running an SPRT"; the `pgrep -f` self-match hazard is in `reckless-working-practice`'s
`references/tooling-gotchas.md`.

Specific to Trebuchet: Jonny asked for status repeatedly during a silent 8-hour validation run (2026-07) and then said he
liked the pawnstar-era practice. This harness's pins are `option.Threads=1 option.Hash=64 option.OwnBook=false`
(Trebuchet has no Ponder option; fastchess does not ponder, so re-verify if either changes). The embedded book made
`OwnBook` semantics richer, which is why it is pinned rather than trusted to its default.
