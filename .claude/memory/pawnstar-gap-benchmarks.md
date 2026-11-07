---
name: pawnstar-gap-benchmarks
description: Trebuchet-vs-pawnstar Elo gaps at various configs (the reference-opponent benchmark)
metadata: 
  node_type: memory
  type: project
  originSessionId: 221925ef-3c7d-4275-96ac-0cd7362cb511
  modified: 2026-07-25T11:08:31.366Z
---

**2026-11-07 (UTC), the current releases: Trebuchet 1.0.0 is +144.30 Elo over Pawnstar 2.2.0, single-thread.**
4,000 games, +1787 =1998 -215, 69.65%, 95% +134.37 to +154.24 allowing for opening correlation (ICC 0.157,
design effect 1.895; nominal +137.09 to +151.52). lin-0 (Ryzen 7 6800H, 8 physical cores), fastchess 1.8.2
alpha, published release binaries frozen and re-hashed, no CI job alongside, 8+0.08, concurrency 7, paired
colours, 306 lines (298 distinct positions) from the TSCP-derived set, draw movenumber=40 movecount=8 score=20,
resign movecount=3 score=600, Threads=1, Hash=64, own book off, game count fixed in advance. Evidence:
`~/sprt/trebuchet-1.0-strength/` on lin-0; its STATUS.md leaves one thing open, 67 unforced Pawnstar moves with
no info line, cause not established. Both sides played one net, SHA-256 `c8a29b328849cd1e...`: `pawnstar-v20.bin`
(run name `runF-pawnstar-sb870`) and `reckless-lc0-runf-sb870.nnue` are the same file, and both binaries embed it.
- **Stoopid Chess 4.1.0, same conditions (Hash=64 only; it has no Threads or book option): 300 games, +292 =4 -4,
  98.00%.** No Elo quoted at that score; win rate at least 0.948 (two-sided 95% Clopper-Pearson, draws as
  non-wins). Cut from 1,000 before any counted game, on a 14-0 pilot, because a one-sided check needs no more.
- **Pawnstar-Go and Pawnstar-RS were not played.** Speed at 7-way occupancy, mean nps: Pawnstar 1,310,183,
  Pawnstar-Go 1,028,355, Pawnstar-RS 720,836. Any claim about those two is inference from bit-exact search and
  lower speed, not games.
- **Comparisons with the July figures below do not attribute to any one cause:** machine, concurrency, both sides'
  nets, both engines' code and the openings all differ. Multi-thread was not re-measured, so +107.5 at 8 threads is
  still July's figure on July's binaries, and nothing here generalises beyond this machine and time control.
- **The "~+135" in older notes was `cap1`, not `cap2`:** it first appears on 2026-07-30 (`65c7e9f`, 800 games per
  book setup, +/-17) with the Makefile's `NET` at `cap1`, and `cap2` shipped on 2026-08-01. No game logs found.

Trebuchet's strength is benchmarked against pawnstar C++ (the reference opponent; user wants Trebuchet stronger). Gaps measured with fastchess, tc=8+0.08, PlentyChess openings.

**GOAL FULLY ACHIEVED (2026-07-23): Trebuchet beats pawnstar at BOTH single thread (+77.7 ± 25.2) and 8 threads
(+107.5 ± 37.8).**

**RECONFIRMED (2026-07-25) vs a freshly-rebuilt pawnstar 0.13.603, and the lead is TIME-CONTROL-INVARIANT.**
The shipped binary (setwise movegen + kb3 + full stack) vs pawnstar 0.13.603 + v12 net, single-thread both,
OwnBook=false, Hash=64, conc 8, SPRT elo[0,5]:
- **8+0.08: +78.07 ± 18.39 (61.05%, 724 games) — H1 accepted.**
- **40/60:  +77.15 ± 16.71 (60.92%, 714 games) — H1 accepted.**
Near-identical at both TCs → the ~+78 single-thread edge is not a fast-TC artifact; it holds at slower control.
(Confirms the +77.7 from 2026-07-23. The setwise movegen and optional PEXT build did not change the picture —
setwise is strength-neutral, PEXT is bit-identical.)

**CRITICAL MEASUREMENT LESSON — pawnstar's UCI defaults are `Threads=32` and `OwnBook=true`.** Every earlier
"single-thread" gap number (−278, −258, −140, −134) never overrode them, so those matches were actually Trebuchet
1-thread vs pawnstar 32-threads(+book) — a measurement artifact, NOT a real deficit. Always pass explicit
`option.Threads=1 option.OwnBook=false` to pawnstar. The corrected single-thread number (2026-07-23, conc 8):
**Trebuchet +77.7 ± 25.2 AHEAD.** Supporting data: single-thread nps parity (trebuchet 2.47M vs pawnstar 2.4–2.5M,
kb3 loaded) and trebuchet reaches depth 20 in 2.7s where pawnstar reaches 17 in 3.1s.

**IMPORTANT — always match `-concurrency` when comparing gap numbers.** Concurrency changes the timed result a lot: pc2 vs pawnstar was −238±52 at conc 30 but −277±44 at conc 8 (same net, same TC). Cross-run comparisons at different concurrency are meaningless.

Single-thread, matched conditions (conc 8):
- **pc2 (512, 190M PlentyChess positions):** −277.5 ± 43.6 vs pawnstar (2026-07-21).
- **kb2 (king buckets, 650M PlentyChess positions):** −257.6 ± 40.7 → kb2 closes ~+20 Elo (eval gain, partial transfer).
- **kb2 + correction history + legality oracle:** **−140.4 ± 34.1** (2026-07-22) → full stack closes ~+137 Elo.
- **+ kb3 + inline EP/castle + SPSA-tuned search (the binary of that date):** **−133.6 ± 32.8** (2026-07-23). The single-
  thread gap is roughly HALVED from −278. Note: kb3 (+8) and SPSA (+26.5) are big SELF-PLAY gains but only nudged
  the pawnstar point estimate (−140→−134, within the ±33 noise) — partial transfer again, and hard to resolve at
  ~300 games. The legality-oracle SPEED win (~1:1 transfer) did most of the −278→−140 closure.
- **kb2 vs pc2 self-play: +63.2 ± 29.7** (consistent with the +57 SPRT that shipped kb2).

Session Elo (self-play SPRT): kb2 +57, correction history +10, legality oracle +66 (~+133 cumulative). The
legality-oracle speed win transferred to pawnstar near 1:1 (speed helps vs any opponent), unlike eval gains
(~1/3 transfer) — which is why the full-stack gap closure (~+137) exceeds kb2's eval-only +20.

8 threads each (Lazy SMP), same conditions (conc 3, 8+0.08):
- pc2 net (2026-07-20): −42 ± 48 vs pawnstar — near-even.
- **kb3 + corrhist + legality + EP/castle + SPSA-tuned (2026-07-23): +107.5 ± 37.8 → TREBUCHET IS STRONGER THAN
  PAWNSTAR AT 8 THREADS.** GOAL ACHIEVED at multi-thread. A +149 Elo swing from the session's work. Trebuchet's
  Lazy SMP scales much better than pawnstar's, so at equal threads the eval+search gains compound into a
  commanding lead — even though single-thread is still −134 (partial transfer of eval gains). See [[trebuchet-goal-independence]].

**Key lesson — self-play gains only partially transfer to a much stronger opponent.** kb2 is +63 vs pc2 in
self-play but only ~+20 better against pawnstar (~1/3 transfer). SPRT self-play deltas OVERSTATE the gain
versus a stronger reference. The single-thread gap to pawnstar is still large (~−258) but narrowing; eval
quality (more/better data, see [[trebuchet-eval-experiments]]) remains the highest-leverage lever. Next data
scale-ups should keep pushing — 650M was 8 of 16 available PlentyChess shards.

**BOTCHED MEASUREMENT (2026-07-27, since corrected):** a "−37.7 ± 18.4" run repeated the exact artifact this
memory warns about — pawnstar was left on its Threads=32 + OwnBook=true defaults. Trebuchet 1-thread scoring
44.6% against THAT is consistent with the true lead growing. ALWAYS pass option.Threads=1
option.OwnBook=false to pawnstar, and match -concurrency (the valid baseline numbers used conc 8).

- **FAIR re-measurement (2026-07-27, correct conditions: both Threads=1, OwnBook=false, Hash=64, conc 8,
  8+0.08, 1000 games): Trebuchet +111.75 ± 15.49 (65.55%).** The lead GREW from +78 (2026-07-25) — the session's
  +43 self-play Elo (SPSA pass 2 +11, qsearch TT +17, ob2 net +15) plus the gated-clock speed win transferred
  to roughly +34 of gap movement. Trebuchet is decisively stronger than pawnstar single-thread.
