# Orchestration templates

Reusable artifacts for `orchestrating-parallel-workstreams`. Adapt; keep them in a `briefs/` dir next to the worktrees. `@<orch>` = the orchestrator's bus name.

---

## `_common.md` — shared rules every implementer brief references
```markdown
# Common rules for every implementer subagent
You are an autonomous implementer subagent. The orchestrator is @<orch> — report progress/blockers/done to @<orch>.

## Sources of truth (read before coding)
- Master plan: <path> (anchors, locked decisions, gotchas). READ IT.
- Spec: <path> (ground truth over any downstream doc).
- Your ticket — pasted in your brief.

## Workspace
- You are launched inside your own git worktree (cwd). Do ALL work here. Do NOT cd into the main repo or another workstream's worktree. Your branch is checked out, based on the integration branch.

## How to work
- TDD: failing test → minimal impl → green → commit. Small reviewable commits.
- Keep changes scoped to your ticket. Don't refactor unrelated code or touch other workstreams' files.

## Reporting
- Milestones: hcom send @<orch> --intent inform.
- BLOCKED / spec-ambiguity / design fork you can't resolve from spec+plan: DO NOT GUESS → hcom send @<orch> --intent request; continue on anything else.
- Done: hcom send @<orch> --intent inform with PR URL + DoD status. (final action — then STOP)

## DoD gate (before "ready")
1. Ticket DoD items pass (tests written + green). 2. `cargo check --workspace --all-targets` (or your project's equivalent) clean; baseline tests not regressed. 3. push branch. 4. open PR to the integration branch. 5. report to @<orch> and STOP.

## Merge policy — NON-NEGOTIABLE
Target the integration branch (never the trunk/`main`). You do NOT merge, do NOT push the integration branch directly, do NOT deploy. Terminal action = PR open → report → stop. Human merges.

## Gotchas
- Don't use three-dot `main...branch` to judge what's merged (hides squash-merges); use two-dot or symbol presence.
- <consensus/determinism + cross-stack gotchas specific to the project>
```

---

## Per-workstream brief
```markdown
# WS-X — <TICKET> — <title> — <model>
Read `_common.md` first. This adds WS-X specifics.

## Worktree & stacking
- Worktree: <path>, branch <branch>. [If stacked:] Base is STACKED on <dep PRs> (approved/frozen, not yet merged); build on <files they added>. Your PR targets the integration branch; until deps merge, the PR diff includes them (reviewers diff the increment). Note the stack order in the PR body.

## Ticket (verbatim)
<paste>

## Plan section
<paste anchors + DoD>

## Spec to read
<file + sections>

## Determinism/security guardrails (if consensus/state code)
<committed-bytes-only, canonical ordering, fail-closed, node-local-not-committed>

## DoD recap
<bullet the exact pass criteria + required tests>
```

---

## Phase-R review brief (per reviewer)
```markdown
# Phase R review — WS-X — <title>
You are a FRESH, independent reviewer in a multi-model consensus gate.
- PR: <url> (branch, base). [Stacked: base = <commit>; review ONLY the increment: `git -C <worktree> diff <base> HEAD` — the dep code is already approved, do NOT re-review it.]
- YOUR OWN worktree (build/test here only): <path>.

## REVIEW ONLY. Do NOT write, edit, create, commit, or push ANY file ANYWHERE. Do not `cd` out of your worktree. You are not given, and must not look for, the integrator's worktree — the orchestrator is the sole writer. If you believe a fix is needed, DESCRIBE it in your report; do not apply it. (You may run read-only build/test in YOUR worktree only.)

## Threat model & scope (read before you start)
<the trust boundary: who/what is trusted vs. adversarial, and what is IN scope vs. OUT of scope for this review. This is here so you check the boundary that matters instead of inventing adversarial cases or rat-holing on out-of-scope attacks.>

## Check (correctness / security / spec+DoD — not style)
<the 4-6 things that matter most, with spec citations; call out any ALREADY-DECIDED items so they aren't relitigated>
- Consider what the change makes REACHABLE, not only the lines it edits (a new capability, a newly-hit path, newly-writable state).
- If the change touches a contract/wire-format/capability, trace its consequence into DOWNSTREAM consumers — including in OTHER repos — not just this repo.

## Evidence bar — applies to your FIXES and NEGATIVE claims, not just your findings
Every finding cites `file:line` you actually read. Hold the other two claim types to the SAME bar:
- **A prescribed fix must cite the code that makes it work.** "Do X instead" with nothing anchored is a hypothesis — label it one. Findings are checkable; the remedies bolted onto them usually aren't, and that asymmetry is where a confident review goes wrong.
- **Never assert absence or unreachability from a diff-local search.** "X isn't possible / doesn't exist / was never meant to work" is a claim about the whole system, but you only read the increment. Either search wider and say what scope you searched, or downgrade it to "I did not find X in <scope>."

## Style
Root each finding in the spec/plan and in works-vs-doesn't. Be collaborative; credit what the PR got right. No model/process meta (no "as an AI", "in this round", "the other reviewer") — the author should see a clean technical review.

## Report to @<orch> — the FILE is your verdict of record; the send is only a notification. The orchestrator reads `REVIEW-<tag>-<model>.md` directly, because bus delivery to @<orch> can silently drop (identity drift). So the file MUST be complete and correctly named even if the send fails. Write first, then send (NEVER inline; backticks/`$()` can trip a CLI shell guard — a known gemini quirk, re-verify for agy — and your message silently never sends):
1. write the full report below to `<your-worktree>/REVIEW-<tag>-<model>.md` (first line `VERDICT: READY` or `VERDICT: BLOCK`)
2. `hcom send @<orch> --intent inform --file <your-worktree>/REVIEW-<tag>-<model>.md`
Format, exactly:
VERDICT(WS-X): ready | changes_requested
CI: green | red | pending
BLOCKING: <numbered, file:line + why; empty if none>
NON-BLOCKING: <optional; do NOT gate>
"ready" = no remaining BLOCKING correctness/security/spec/DoD issue (not aesthetic consensus).
```

---

## `STATUS.md` skeleton (the live tracker + human handoff)
```markdown
# <Project> — Orchestration STATUS
## ✅/⏳ <one-line state>. Merge order (all SQUASH): <repo: #PR(dep)→…>. Nothing merged/deployed.
**Merge policy:** agents PR to the integration branch only; no agent merges/deploys. Human merges.

## Workstream board
| WS | Ticket | Repo | Agent | State | Branch | Notes |
(state: todo · in-flight · Phase-R · APPROVED · blocked)

## Merge guide (for the human) — squash; dependency order; stacked-PR CONFLICTING is expected, resolves on in-order merge.

## Integration-gate wiring — the cross-cutting live-wiring step no single PR owns (spans several stacked PRs).

## Phase-R ledger
| PR | WS | claude | codex | agy | extra | CI | Round | Verdict |

## DECISIONS-NEEDED (parked for human) — genuine forks only.
## Resolved by orchestrator (FYI) — calls made + grounding (esp. things verified against source).
## Fast-follow / integration watch — non-blocking items for later.
## Event log — dated state changes.
```
