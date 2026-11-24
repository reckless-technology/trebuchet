---
name: setwise-elegance-nonregression-gate
description: "Jonny values architectural elegance (e.g. setwise bitboard movegen) and ships such refactors on a NON-regression SPRT, not a gain test"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 221925ef-3c7d-4275-96ac-0cd7362cb511
  modified: 2026-07-25T05:55:36.169Z
---

The rule (an architectural refactor with no intended strength change ships on a non-regression SPRT, `ELO0=-5 ELO1=0`,
not the default `[0, 5]` gain bounds) is in the `reckless-chess-engines` skill, "Running an SPRT", with Jonny's quotation.

Specific to Trebuchet: the example was the setwise bitboard-shift pawn move generation replacing the per-pawn loop
(July 2026); a neutral gain test was mid-run when he said it. Run it as `ELO0=-5 ELO1=0 tools/sprt.sh`. See
[[spsa-tuning]] and [[trebuchet-eval-experiments]] for the gain-test side.
