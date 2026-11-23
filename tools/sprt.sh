#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Jonny Reckless
# Self-play / cross-engine SPRT via fastchess (cutechess-cli is not installed on this box). Measures the
# Elo of a change: a candidate engine/net vs a baseline. Works for:
#   * new net vs shipped: CAND=./build/trebuchet CAND_NET=nets/x.nnue  BASE=./build/trebuchet          (BASE_NET unset -> embedded net)
#   * version vs version: two trebuchet binaries
#   * vs pawnstar:      BASE=/home/jonny/work/pawnstar/build/pawnstar BASE_NET=.../pawnstar-v12.bin
#
# Usage:  tools/sprt.sh [rounds]
# Env:    CAND (default ./build/trebuchet), BASE (default ./build/trebuchet-base), CAND_NET, BASE_NET (EvalFile paths),
#         TC (default 8+0.08), ELO0/ELO1 (default 0/5), CONCURRENCY, HASH, OPENINGS (optional, see below).
#
# Openings: by default the set pinned in tools/openings.pin (Pawnstar's, at a commit, with its SHA-256) is
#   fetched once into build/openings/, verified, and its '#' comment lines stripped. A missing set or a hash
#   mismatch stops the run. OPENINGS=/path/to/file.epd (or .pgn) overrides it for a one-off, unverified, and
#   the run line says so; do not quote a result from an unpinned set as the pinned one.
#
# Every engine option a measurement depends on is pinned below rather than left to the UCI default, the
# same way `pawnstar/tools/pawnstar-match.sh` does it. Threads especially: trebuchet's own default is
# `platform_cpu_count() / 2` (src/uci.c), so an unpinned run on a 16-CPU machine plays 8-thread engines -
# and with CONCURRENCY also sized from nproc, it oversubscribes the box by an order of magnitude and
# reports scheduler noise as Elo. A harness pins Threads=1; src/uci.c's own comment says so.
set -euo pipefail

CAND="${CAND:-./build/trebuchet}"
BASE="${BASE:-./build/trebuchet-base}"
ROUNDS="${1:-2000}"
TC="${TC:-8+0.08}"
ELO0="${ELO0:-0}"
ELO1="${ELO1:-5}"
OPENINGS="${OPENINGS:-}"
HASH="${HASH:-16}"
# One game per physical core, less one for fastchess itself, assuming SMT (nproc counts hyperthreads).
# On reckless-ci-lin-0 (16 logical / 8 physical) that is 7, which measured 1.28 M nps per engine against
# ~1.3 M idle (2026-10-30). The previous `nproc - 2` default was 14 there, and a 14-way run in an earlier
# campaign on that machine left each engine at 44-47% of its idle rate - enough to swamp the Elo
# difference the run exists to measure. Set CONCURRENCY explicitly on a machine without SMT.
logical_cpus="$(nproc)"
CONCURRENCY="${CONCURRENCY:-$(( logical_cpus / 2 - 1 > 0 ? logical_cpus / 2 - 1 : 1 ))}"

FASTCHESS="$(command -v fastchess || true)"
[ -z "$FASTCHESS" ] && [ -x "$HOME/pawnstar_nnue/fastchess/fastchess" ] && FASTCHESS="$HOME/pawnstar_nnue/fastchess/fastchess"
[ -z "$FASTCHESS" ] && { echo "fastchess not found (PATH or ~/pawnstar_nnue/fastchess/fastchess)" >&2; exit 1; }

for engine in "$CAND" "$BASE"; do
    command -v "$engine" >/dev/null 2>&1 || [ -x "$engine" ] || { echo "missing engine: $engine" >&2; exit 1; }
done
# Openings: the pinned set unless OPENINGS overrides it. fastchess needs EPD or PGN (the Polyglot books under
# books/ are not one), and without openings every game would start from the same position.
script_directory="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
pin_file="$script_directory/openings.pin"
openings_format=epd
if [ -n "$OPENINGS" ]; then
    [ -f "$OPENINGS" ] || { echo "tools/sprt.sh: missing openings: $OPENINGS" >&2; exit 1; }
    case "$OPENINGS" in *.pgn) openings_format=pgn ;; esac
    openings_label="$OPENINGS (NOT the pinned set)"
else
    [ -f "$pin_file" ] || { echo "tools/sprt.sh: missing $pin_file, which names the opening set" >&2; exit 1; }
    pin_value() {
        local value
        value="$(sed -n "s/^$1=//p" "$pin_file")"
        [ -n "$value" ] || { echo "tools/sprt.sh: $pin_file has no $1" >&2; exit 1; }
        printf '%s' "$value"
    }
    pinned_repository="$(pin_value OPENINGS_REPOSITORY)"
    pinned_commit="$(pin_value OPENINGS_COMMIT)"
    pinned_path="$(pin_value OPENINGS_PATH)"
    pinned_sha256="$(pin_value OPENINGS_SHA256)"
    cache_directory="$script_directory/../build/openings"
    raw_file="$cache_directory/$pinned_commit.epd"
    OPENINGS="$cache_directory/$pinned_commit.stripped.epd"
    mkdir -p "$cache_directory"
    if [ -f "$raw_file" ] && [ "$(sha256sum "$raw_file" | cut -d' ' -f1)" != "$pinned_sha256" ]; then
        rm -f "$raw_file"  # a damaged cache is refetched, and checked again below
    fi
    if [ ! -f "$raw_file" ]; then
        url="https://raw.githubusercontent.com/$pinned_repository/$pinned_commit/$pinned_path"
        curl -fsSL --retry 3 -o "$raw_file.part" "$url" || { rm -f "$raw_file.part"; echo "tools/sprt.sh: could not fetch the pinned openings from $url" >&2; exit 1; }
        mv "$raw_file.part" "$raw_file"
    fi
    actual_sha256="$(sha256sum "$raw_file" | cut -d' ' -f1)"
    if [ "$actual_sha256" != "$pinned_sha256" ]; then
        echo "tools/sprt.sh: opening set hash mismatch: expected $pinned_sha256, got $actual_sha256 ($pinned_repository@$pinned_commit:$pinned_path)" >&2
        rm -f "$raw_file"
        exit 1
    fi
    grep -v '^#' "$raw_file" > "$OPENINGS"
    [ -s "$OPENINGS" ] || { echo "tools/sprt.sh: the pinned opening set has no positions" >&2; exit 1; }
    openings_label="$pinned_repository@${pinned_commit:0:12}:$pinned_path sha256=${pinned_sha256:0:12} ($(wc -l < "$OPENINGS") positions)"
fi

# Optional per-engine EvalFile (NNUE net). Absent => that side uses its default (trebuchet: the embedded net).
cand_net_arg=(); [ -n "${CAND_NET:-}" ] && cand_net_arg=(option.EvalFile="$CAND_NET")
base_net_arg=(); [ -n "${BASE_NET:-}" ] && base_net_arg=(option.EvalFile="$BASE_NET")
# Optional per-engine working directory (e.g. pawnstar loads its net via a relative path).
cand_dir_arg=(); [ -n "${CAND_DIR:-}" ] && cand_dir_arg=(dir="$CAND_DIR")
base_dir_arg=(); [ -n "${BASE_DIR:-}" ] && base_dir_arg=(dir="$BASE_DIR")

echo "SPRT  cand=$CAND ${CAND_NET:+net=$CAND_NET}  base=$BASE ${BASE_NET:+net=$BASE_NET}  TC=$TC elo[$ELO0,$ELO1] rounds=$ROUNDS"
echo "      Threads=1 Hash=${HASH}MB OwnBook=false per engine, concurrency=$CONCURRENCY, openings=$openings_label"
exec "$FASTCHESS" \
    -engine cmd="$CAND" name=cand "${cand_net_arg[@]}" "${cand_dir_arg[@]}" \
    -engine cmd="$BASE" name=base "${base_net_arg[@]}" "${base_dir_arg[@]}" \
    -each proto=uci tc="$TC" option.Threads=1 option.Hash="$HASH" option.OwnBook=false \
    -rounds "$ROUNDS" -games 2 -repeat \
    -openings file="$OPENINGS" format=$openings_format order=random \
    -draw movenumber=40 movecount=8 score=20 -resign movecount=3 score=600 \
    -sprt elo0="$ELO0" elo1="$ELO1" alpha=0.05 beta=0.05 \
    -concurrency "$CONCURRENCY" -ratinginterval 20
