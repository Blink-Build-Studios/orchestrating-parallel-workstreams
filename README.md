# Orchestrating Parallel Workstreams

A [Claude Code](https://code.claude.com) skill for running one **high-context orchestrator** that drives many autonomous coding agents — one per workstream, each in its own git worktree — from a master plan, pipelines their PRs through a multi-model adversarial review gate, and surfaces only the decisions that genuinely need a human. The orchestrator dispatches, verifies, adjudicates, and replans. **It does not implement, merge, or deploy.**

> **Companion essay:** *"I Don't Manage Coding Agents. I Manage an AI Staff Engineer."* — <!-- TODO: link once published --> `https://blog.blinkbuild.ai/`
> The essay is the *why* (the mental model — an AI staff engineer, not a swarm). This repo is the *how* (the operational doctrine and the runbook).

## What it is

- **A doctrine** ([`SKILL.md`](SKILL.md)) for decomposing a plan into dependency-ordered waves, dispatching one autonomous agent per workstream, and gating every PR through independent multi-model review — without the human becoming a message broker.
- **Two named per-PR commands:**
  - **Phase R** — one advisory review round. Fresh reviewers inspect the PR, write verdict files, report. *They do not fix.*
  - **Phase G** ("grind to green") — loops the gate, applies one-writer fixes between rounds, and drives the PR to landable or escalates. Owns the outcome.
- **Templates** ([`orchestration-templates.md`](orchestration-templates.md)) — the shared implementer rules, per-workstream brief, review brief, and the live `STATUS.md` tracker.
- **A host runbook + spawn script** ([`phase-r-runbook.md`](phase-r-runbook.md), [`phase-r-spawn.sh`](phase-r-spawn.sh)) — the concrete "how to spawn headless agents on one machine," including the traps that look like flaky models but are really topology or plumbing.

## What it is *not*

- Not for a single small change, work needing no isolation, or anything you'll merge yourself immediately.
- Not an auto-merger. Every PR ends at "ready to land"; a human lands it.
- Not a vote-counter. Reviewer unanimity is the *exit condition*, not the method — contested findings are adjudicated against the source, never by majority.

## Prerequisites

This skill is written against a specific reference stack. You supply these yourself:

- **An agent bus** that can spawn headless CLI coding agents and route messages between them. The reference is [`hcom`](https://github.com/) <!-- TODO: link your bus -->; the doctrine is bus-agnostic.
- **Three coding-agent CLIs** for the review roster: `claude`, `codex`, and `agy` (antigravity). Any 2–4 independent models work; three from different families is the sweet spot.
- **`git` with worktrees** and **`gh`** (GitHub CLI) for PR/CI inspection.
- A machine that can run several headless agents concurrently.

The runbook names **exact CLI flags and bus quirks that were true at a point in time.** CLIs drift — re-verify flags (`--help`) and behavior against your live tools before relying on them.

## Install

This repo is both a standalone skill (`SKILL.md` at the root) **and** a self-contained Claude Code plugin marketplace (`.claude-plugin/`), so it installs several ways. Skills use the cross-tool [Agent Skills](https://code.claude.com/docs/en/skills) format, so both Claude Code and Codex can consume it.

> The repo must be reachable by whoever installs it — public, or the user git-authed to a private repo. Every one-command path below needs that.

### Claude Code — one command (plugin)

```text
/plugin marketplace add Blink-Build-Studios/orchestrating-parallel-workstreams
/plugin install orchestrating-parallel-workstreams@orchestrating-parallel-workstreams
```

### Codex — one command

Inside Codex, install from the GitHub repo with the skill installer:

```text
$skill-installer Blink-Build-Studios/orchestrating-parallel-workstreams
```

### Manual (either tool) — clone into the skills dir

```sh
# Claude Code
git clone https://github.com/Blink-Build-Studios/orchestrating-parallel-workstreams.git \
  ~/.claude/skills/orchestrating-parallel-workstreams

# Codex CLI
git clone https://github.com/Blink-Build-Studios/orchestrating-parallel-workstreams.git \
  ~/.codex/skills/orchestrating-parallel-workstreams
```

### Cross-tool package manager

```sh
npx skills add Blink-Build-Studios/orchestrating-parallel-workstreams
```

Once installed, invoke it by describing an orchestration task, or by typing **"Phase R #N"** / **"Phase G #N"** at a PR.

## The core ideas (why it holds together)

- **One branch, one writer.** A capable autonomous reviewer will act on the affordances you give it — if it can reach a writable branch, it may "help" and cause a multi-writer collision. That's a topology failure, not a flaky model. Isolate reviewers with no writable path to the branch under review.
- **File-first verdicts.** Each reviewer writes `REVIEW-<tag>-<model>.md` in its worktree; the bus message is only a "go look" ping. A long-running bus can silently drift or drop an identity — *"no message arrived" is not "no review happened."* Poll the files.
- **Adjudicate, don't vote.** Every material finding must be a concrete, checkable claim anchored to `file:line`. The same evidence bar applies to prescribed fixes ("do X instead" must cite the code that makes X work) and to negative claims ("that path is unreachable" must state the scope searched).
- **Observed green, not "looks fixed."** A green check is only evidence for the paths the workflow actually ran. If CI never exercised the changed path, say so.
- **Escalate the smallest decision that remains.** The orchestrator resolves what the plan, spec, source, and tests can decide; it escalates genuine product forks, conflicting sources of truth, scope/risk changes, and locked-decision reversals.
- **Models have roles, not rankings.** Best implementer ≠ best critic ≠ best orchestrator. Assign models to roles; make the extra high-stakes reviewer a *different* model than the author.

## Adapting it to your setup

The files name specific tools as a reference implementation, but the doctrine is tool-agnostic:

- Swap `hcom` for your bus (the identity-drift and file-first-verdict lessons apply to any long-lived agent bus).
- Swap the model roster; keep "3 fresh, independent, different-family reviewers."
- `phase-r-spawn.sh` takes `<orch> <repo> <pr> <tag> [wt_base]` and expects worktrees at `<wt_base>/wt-<tag>-{claude,codex,agy}`; adjust paths/tools to taste.
- The approval-hook section (`§4` of the runbook) only applies if your host runs a `PreToolUse` approval hook — skip it otherwise.

## Status & warranty

Provided **as-is, without warranty of any kind.** This is a working practitioner's skill, not a supported product. The flag tables, bus behaviors, and tool quirks are snapshots that will bit-rot; treat them as a starting point and verify against your own tools. Issues and PRs welcome, but response is best-effort.

## License

Released into the public domain under [The Unlicense](UNLICENSE). Use it however you want, no attribution required, no warranty.
