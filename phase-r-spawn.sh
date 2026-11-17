#!/usr/bin/env bash
# phase-r-spawn.sh — launch the tri-model Phase-R gate (claude + codex + agy) for ONE PR,
# implementing optimizations #1 + #2:
#   #1 PARALLEL  — all three hcom spawns fire concurrently (not sequentially), so the
#                  wall-clock is max(launch) ≈ 10s, not sum ≈ 25–30s.
#   #2 NON-BLOCK — each launcher is nohup-backgrounded and this script returns IMMEDIATELY
#                  without sitting in any per-launch "waiting for readiness" window. The
#                  "<hcom> all instances ready" messages arrive asynchronously on the bus.
#
# Used by BOTH Phase R (one round) and Phase G (every round re-runs this gate), so wiring
# the speedup here improves both. See phase-r-runbook.md §2 (spawn), §3 (agy prompt), §8 (Phase G).
#
# This script ONLY launches. Do the per-PR setup first (fetch branch, create the three
# review worktrees, drop a shared BRIEF.md into each) and be joined to the bus as <orch>.
#
# Usage:
#   phase-r-spawn.sh <orch> <repo> <pr> <tag> [wt_base]
#     orch     hcom name of the orchestrator the reviewers report to (e.g. orch1)
#     repo     owner/name for gh (e.g. acme/widgets)
#     pr       PR number (e.g. 167)
#     tag      hcom group tag for this gate (e.g. rev167)
#     wt_base  dir holding the worktrees (default: $PWD); the script expects
#              <wt_base>/wt-<tag>-{claude,codex,agy}, each containing BRIEF.md
#
# Optional environment (host values belong in LOCAL.md, not here):
#   PHASE_R_CLAUDE_MODEL     model passed as `--model` to EVERY claude reviewer this script
#                            launches (the trio's claude + every extra reviewer below).
#                            codex/agy are unaffected. Unset = the CLI's default.
#   PHASE_R_EXTRA_REVIEWERS  space-separated `label[=abs-worktree-path]` entries. Each adds
#                            ONE more claude reviewer that runs a review SKILL named in its
#                            BRIEF.md (e.g. a repo's merge-gate skill) rather than the trio's
#                            read-only-diff brief. Its worktree defaults to
#                            <wt_base>/wt-<tag>-<label>; give a path when the skill's tooling
#                            keys on it. Must contain BRIEF.md. Labels must not be
#                            claude/codex/agy. Verdict file: REVIEW-<tag>-<label>.md, first
#                            line VERDICT: READY | BLOCK | ESCALATE [(degraded: <stage>)].
#                            An extra reviewer is an advisory 4th lens for the orchestrator's
#                            adjudication, NOT part of the trio's 3/3 quorum.
#   PHASE_R_DIFF_CMD         the command reviewers are told to run to read the diff. Default:
#                            `gh pr diff <pr> --repo <repo>` (GitHub). On another forge set it,
#                            e.g. GitLab: PHASE_R_DIFF_CMD="glab mr diff <mr> -R <group/project>".
#   PHASE_R_DRY_RUN=1        print the hcom launch lines instead of executing them (no PID
#                            lines are emitted). For checking prompts/paths/model wiring.
#
# Example:
#   phase-r-spawn.sh orch1 acme/widgets 167 rev167 /path/to/worktrees
set -euo pipefail

ORCH="${1:?orch name}"; REPO="${2:?owner/repo}"; PR="${3:?pr number}"; TAG="${4:?tag}"
WT_BASE="${5:-$PWD}"

WT_CLAUDE="$WT_BASE/wt-$TAG-claude"
WT_CODEX="$WT_BASE/wt-$TAG-codex"
WT_AGY="$WT_BASE/wt-$TAG-agy"

CLAUDE_MODEL="${PHASE_R_CLAUDE_MODEL:-}"
DRY_RUN="${PHASE_R_DRY_RUN:-0}"
DIFF_CMD="${PHASE_R_DIFF_CMD:-gh pr diff $PR --repo $REPO}"

# Pre-flight: a reviewer with no brief is useless — fail fast, clearly, before launching.
for wt in "$WT_CLAUDE" "$WT_CODEX" "$WT_AGY"; do
  [ -f "$wt/BRIEF.md" ] || { echo "ERROR: missing $wt/BRIEF.md — create the worktrees + brief first" >&2; exit 1; }
done

# Extra skill-driven reviewers (PHASE_R_EXTRA_REVIEWERS): parse + pre-flight BEFORE any
# launch, so a bad entry fails the whole gate cleanly instead of after three agents are up.
# Parallel indexed arrays + a counter (bash 3.2-safe: no associative arrays, and no
# "${arr[@]}" on a possibly-empty array under `set -u`).
N_EXTRA=0
for entry in ${PHASE_R_EXTRA_REVIEWERS:-}; do
  label="${entry%%=*}"; path="${entry#*=}"
  [ "$path" = "$entry" ] && path="$WT_BASE/wt-$TAG-$label"
  case "$label" in
    ""|*[!A-Za-z0-9_-]*) echo "ERROR: bad extra-reviewer label '$label' in PHASE_R_EXTRA_REVIEWERS (use [A-Za-z0-9_-])" >&2; exit 1 ;;
    claude|codex|agy)    echo "ERROR: extra-reviewer label '$label' collides with the trio" >&2; exit 1 ;;
  esac
  case "$path" in /*) ;; *) echo "ERROR: extra reviewer '$label' worktree must be an ABSOLUTE path (got '$path')" >&2; exit 1 ;; esac
  [ -f "$path/BRIEF.md" ] || { echo "ERROR: missing $path/BRIEF.md for extra reviewer '$label' — create the worktree + brief first" >&2; exit 1; }
  EXTRA_LABEL[$N_EXTRA]="$label"; EXTRA_PATH[$N_EXTRA]="$path"
  N_EXTRA=$((N_EXTRA + 1))
done

# Identity guard (see phase-r-runbook.md §9): reviewers report to @$ORCH, but the
# ORCHESTRATOR's own bus identity can drift off its friendly name during a long,
# subagent-heavy session. If this shell no longer resolves to $ORCH, the reviewers'
# `hcom send @$ORCH` verdicts land with delivered_to:[] and vanish with NO error — the
# gate looks stalled ("no verdicts") when the verdicts were produced and dropped. Warn
# loudly; don't block (the REVIEW-$TAG-*.md files are the durable, identity-immune channel).
self_now="$(hcom list self name 2>/dev/null || true)"
if [ "$self_now" != "$ORCH" ]; then
  echo "WARNING: hcom self is '${self_now:-<unresolved>}', not '$ORCH' — your bus identity has drifted." >&2
  echo "         Verdicts sent to @$ORCH will SILENTLY drop (delivered_to:[]). Reclaim BEFORE trusting the bus:" >&2
  echo "           hcom start --as $ORCH        # then re-verify:  hcom list self" >&2
  echo "         Regardless, collect verdicts by READING $WT_BASE/wt-$TAG-*/REVIEW-$TAG-*.md (identity-immune)." >&2
fi

# Standard read-only reviewer prompt (claude/codex): read BRIEF.md, review the diff
# read-only, write its report, report it via `hcom send --file`.
# NB: the report filename is REVIEW-<tag>-<model>.md (tag-scoped, NOT just
# REVIEW-<model>.md) so that N gates running concurrently don't produce three files
# with the same basename — hcom's multi-writer collision detector keys on the name and
# would false-alarm on same-named files across separate worktrees.
common_prompt() {  # $1 = model label
  printf '%s' "You are a FRESH, INDEPENDENT, READ-ONLY reviewer for $REPO PR #$PR. Read ./BRIEF.md in your worktree and follow it EXACTLY. STATIC review only: do NOT edit/checkout/commit/push or write any file except your own report; do NOT cd outside your worktree. Get the diff with: $DIFF_CMD . Write your full review to ./REVIEW-$TAG-$1.md (first line: 'VERDICT: READY' or 'VERDICT: BLOCK'), then report it with: hcom send @$ORCH --intent inform --file ./REVIEW-$TAG-$1.md . Do not merge."
}

# agy needs the FORCEFUL front-loaded prompt (names the exact hcom command, forbids the
# CLI-discovery detour) — see phase-r-runbook.md §3. Ack first, then review, then report.
#
# ⚠ agy MUST get ABSOLUTE paths. Unlike claude/codex, whose cwd IS --dir, antigravity's
# TOOL cwd is its own scratch dir (~/.gemini/antigravity-cli/scratch) — it treats --dir as
# a "workspace" (the folder-trust dialog names it) but does not chdir there. So a relative
# "./BRIEF.md" resolves to nothing and agy falls back to hunting for the file: observed
# running `find / -name BRIEF.md` for many minutes before being killed. Looks exactly like
# a hung/flaky model; is actually a bad path.
agy_prompt() {
  # NB: --intent inform, NOT --intent ack — a fresh agent's first send has nothing to
  # reply to, and `--intent ack` HARD-FAILS with "requires --reply-to".
  printf '%s' "Your VERY FIRST action - before reading ANY file, before running hcom --help / hcom status / hcom list / hcom send --help - must be to run this EXACT command (it is already correct, do NOT verify it): hcom send @$ORCH --intent inform -- \"agy starting review of $REPO $PR\" . THEN read the file at this EXACT ABSOLUTE path - it is already correct, read it DIRECTLY and do NOT run find/ListDir to locate it: $WT_AGY/BRIEF.md . Follow it EXACTLY as a FRESH, INDEPENDENT, READ-ONLY reviewer of $REPO PR #$PR. Your worktree is $WT_AGY - use ABSOLUTE paths for every file you touch; do NOT assume your shell cwd is the worktree. STATIC review ONLY: do NOT run cargo/docker build or tests, do NOT checkout/edit/commit/push, do NOT write any file except your report, do NOT read or write anything outside $WT_AGY. Read the diff via: $DIFF_CMD . Write your full review to $WT_AGY/REVIEW-$TAG-agy.md (first line: 'VERDICT: READY' or 'VERDICT: BLOCK'). Your FINAL action must be this EXACT command (already correct, do NOT verify it): hcom send @$ORCH --intent inform --file $WT_AGY/REVIEW-$TAG-agy.md . Do not merge."
}

# Skill-driven extra reviewer prompt (claude). Deliberately NOT the read-only-diff
# profile: a review skill may legitimately build, run tests, create its own scratch
# worktrees and spawn subagents — the BRIEF says exactly what is allowed. What is never
# allowed: commit/push, touching any branch, or posting to the PR (the orchestrator
# adjudicates first). Absolute paths throughout, same reason as agy.
skill_prompt() {  # $1 = label  $2 = worktree (absolute)
  printf '%s' "You are an INDEPENDENT reviewer for $REPO PR #$PR running a review SKILL, not a diff read. Read the brief at this EXACT ABSOLUTE path and follow it EXACTLY: $2/BRIEF.md . Your worktree is $2 - use ABSOLUTE paths. Work only there and in scratch worktrees the brief explicitly allows; you may run builds/tests and spawn subagents only as the brief allows. Do NOT commit or push anything, do NOT modify any branch, do NOT post to the PR/MR or anywhere on the code host. Write your full report to $2/REVIEW-$TAG-$1.md (first line EXACTLY one of: 'VERDICT: READY' / 'VERDICT: BLOCK' / 'VERDICT: ESCALATE', optionally followed by ' (degraded: <stage>)'), then report it with this EXACT command: hcom send @$ORCH --intent inform --file $2/REVIEW-$TAG-$1.md . Do not merge."
}

LOGDIR="${TMPDIR:-/tmp}"
launch() {  # $1=tool  $2=worktree  $3=autonomy-flag  $4=prompt  $5=label (PID line + log name)  $6=model (optional; claude only)
  local tool="$1" wt="$2" flag="$3" prompt="$4" label="$5" model="${6:-}"
  if [ "$DRY_RUN" = "1" ]; then
    printf 'DRY-RUN %s: hcom 1 %s --tag %s --dir %s --headless --hcom-prompt %q %s%s --go --name %s\n' \
      "$label" "$tool" "$TAG" "$wt" "$prompt" "$flag" "${model:+ --model $model}" "$ORCH"
    return 0
  fi
  # nohup + redirect + </dev/null + & + disown: the launcher survives this script's exit
  # (no SIGHUP) and never blocks on stdin, so the spawn truly runs detached (#2).
  # `--model` only when set (bash 3.2: no empty-array expansion under set -u).
  if [ -n "$model" ]; then
    nohup hcom 1 "$tool" --tag "$TAG" --dir "$wt" --headless --hcom-prompt "$prompt" "$flag" --model "$model" --go --name "$ORCH" \
      >"$LOGDIR/phase-r-$TAG-$label.log" 2>&1 </dev/null &
  else
    nohup hcom 1 "$tool" --tag "$TAG" --dir "$wt" --headless --hcom-prompt "$prompt" "$flag" --go --name "$ORCH" \
      >"$LOGDIR/phase-r-$TAG-$label.log" 2>&1 </dev/null &
  fi
  local pid=$!
  disown
  # Machine-parseable PID line: nohup execs hcom directly (no intermediate
  # fork), so $! captured immediately after the backgrounding `&` -- before
  # `disown` -- is the real hcom PID. A caller with no other way to bound
  # or stop a runaway reviewer (e.g. an external timeout supervisor) greps this.
  echo "PID $label $pid"
}

# Fire all three CONCURRENTLY (#1); do not `wait` (#2).
launch claude      "$WT_CLAUDE" --dangerously-skip-permissions              "$(common_prompt claude)" claude "$CLAUDE_MODEL"
launch codex       "$WT_CODEX"  --dangerously-bypass-approvals-and-sandbox  "$(common_prompt codex)"  codex
launch antigravity "$WT_AGY"    --dangerously-skip-permissions              "$(agy_prompt)"           agy

# Extra skill-driven reviewers (claude), same model knob, concurrently with the trio.
i=0
while [ "$i" -lt "$N_EXTRA" ]; do
  launch claude "${EXTRA_PATH[$i]}" --dangerously-skip-permissions "$(skill_prompt "${EXTRA_LABEL[$i]}" "${EXTRA_PATH[$i]}")" "${EXTRA_LABEL[$i]}" "$CLAUDE_MODEL"
  i=$((i + 1))
done

echo "Phase-R gate launching (parallel + backgrounded, non-blocking) — $REPO #$PR  tag:$TAG -> @$ORCH${CLAUDE_MODEL:+  (claude model: $CLAUDE_MODEL)}"
echo "  claude      -> $WT_CLAUDE"
echo "  codex       -> $WT_CODEX"
echo "  antigravity -> $WT_AGY"
i=0
while [ "$i" -lt "$N_EXTRA" ]; do
  printf '  %-11s -> %s  (skill reviewer, claude; advisory)\n' "${EXTRA_LABEL[$i]}" "${EXTRA_PATH[$i]}"
  i=$((i + 1))
done
echo "Readiness pings arrive async on the bus ('all instances ready')."
echo "VERDICTS: read them from <each worktree>/REVIEW-$TAG-<label>.md — that FILE is the record;"
echo "          the bus 'hcom send @$ORCH' is only a notification and drops silently on identity drift (runbook §9)."
echo "Per-launcher logs: $LOGDIR/phase-r-$TAG-<label>.log  (labels: claude codex agy${N_EXTRA:+ + extras})"
