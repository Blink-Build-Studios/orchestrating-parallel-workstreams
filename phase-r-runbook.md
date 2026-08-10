# Phase-R / headless-agent runbook

Host-specific execution detail for spawning headless agents — implementers (step 2 of [the loop](SKILL.md)) and reviewers (the Phase-R gate) — and operating the multi-model gate on one machine. `SKILL.md` is the model-agnostic doctrine; **this file is the "how, on this box, right now."** The tool names (`hcom`, `claude`, `codex`, `agy`) and flags below were verified against specific tool builds at specific dates — **re-verify flags/paths against the live tools before relying on them**; CLIs drift.

Notation: `<orch>` = the orchestrator's bus name. `$WT_BASE` = the directory that holds your review/worktree tree (no default is assumed; pass it explicitly). `<repo>` = `owner/name` for `gh`.

---

## 1. Model roster: claude + codex + **agy** (NOT gemini)
The tri-model gate is **`claude` + `codex` + `agy` (antigravity)**. `agy` replaced `gemini` on the CLI. hcom spawns all three directly (`hcom 1 agy …`). Wherever older notes say `gemini`/`--yolo`, read `agy`/`--dangerously-skip-permissions`. The old gemini shell-guard quirk (command-substitution blocked → inline `hcom send` silently refused) was gemini-specific; re-verify whether agy has it, but **mandating `hcom send --file` for any report containing code/`§`/backticks/`$()` is the safe default regardless of model.**

## 2. Spawning — PREFER hcom-spawn over direct CLI
Spawn all three via `hcom` so they share the bus (`hcom list -v`, `hcom send --file` verdicts). **Don't default to the direct-CLI workaround in §5.**

**Launch all three IN PARALLEL + BACKGROUNDED — use [`phase-r-spawn.sh`](phase-r-spawn.sh).** Spawning one `hcom … --go` at a time, each blocking ~10s on its readiness wait, wastes ~25–30s; firing all three concurrently and returning immediately cuts that to ≈ max(launch). `phase-r-spawn.sh <orch> <repo> <pr> <tag> <wt_base>` (this skill dir) does exactly that: it `nohup`-backgrounds the three spawns concurrently with the right per-tool autonomy flags + the agy front-load prompt, pre-flights that each worktree has a `BRIEF.md`, and **returns in <1s** — the `<hcom> all instances ready` injections + verdicts arrive async on the bus. **Both Phase R and Phase G (every round) call this same gate, so the speedup applies to both.** Two gotchas it handles for you: (a) **run the `.sh`** — its `#!/usr/bin/env bash` shebang makes `& disown` clean; do NOT hand-paste the `& disown` pattern into a raw Bash-tool call if your interactive shell is **zsh** (it warns `disown: no current job` — cosmetic — the nohup'd spawns still launch); (b) it expects worktrees at `$WT_BASE/wt-<tag>-{claude,codex,agy}`. The manual one-at-a-time form below stays as the flag reference / fallback.

```
hcom 1 <claude|codex|antigravity> --tag <ws> --dir <worktree> --headless \
  --hcom-prompt "<short: read brief PATH; review read-only; report to @<orch> via hcom send --file>" \
  <AUTONOMY-FLAG> --go --name <orch>
```

**Verified hcom-spawn details:**
- **`--go` is required** — without it you get a preview, not a launch.
- **Per-tool AUTONOMY-FLAG** (wrong flag → "exited 0s after spawn before binding"):

  | tool | autonomy flag | NOT |
  |---|---|---|
  | claude | `--dangerously-skip-permissions` | (still hit by an approval hook if the host has one — see §4) |
  | codex | `--dangerously-bypass-approvals-and-sandbox` | NOT `--sandbox read-only` (dies headless) |
  | antigravity / agy | `--dangerously-skip-permissions` | NOT `--yolo` (gemini's old flag → agy exits 2) |

- **All three run full-access**, so enforce read-only by **PROMPT + a detached/own worktree** with NO writable path to the branch under review (see §6). Reviewers report back over the bus (you receive `<hcom>` injections) AND write `REVIEW-<tag>-<model>.md` in their worktree — **that file is the verdict of record, not a fallback**; the bus send is only a "go look" ping and can silently vanish if your bus identity drifts (**§9** — read this if a verdict ever seems "missing").
- `--name <orch>` on every call — and on the orchestrator's OWN `hcom send/list/events` too, not just spawns (§9).
- **Resuming an agent (`hcom r <name>`) that exits `:other` in <1s is a cwd mismatch**, not a dead agent — hcom resume must run from the same working dir the agent started in. Retry with `hcom r <name> --dir <its-start-dir> --go`.

## 3. agy BOOTS fast — the only latency is an UN-PROMPTED first hcom send (fix = the PROMPT)
**agy's own startup is fast (<5s in a plain terminal); "agy is slow to warm up" was a misread of *time-to-first-hcom-send*, not boot time.** The latency only appears when a headless agy is spawned WITHOUT a prompt that hands it the bus command: antigravity ignores the injected hcom context and **re-derives the CLI from scratch** — it burns ~30s on `hcom --help` → `hcom status` → `hcom list` → `hcom send --help` (plus `list_dir`/`view_file`) BEFORE its first send, so a 25s `hcom listen` expires first and it *looks* dead. That's a bus-integration detour, not the process being slow. **With the front-loaded prompt below the detour disappears** — measured 46s → ~10s, and in one gate agy was the FIRST of the three models to deliver a verdict. (A *plain* mention of the command does NOT stop the exploration — tested; it must be the forceful phrasing.)

- **THE FIX (cleanest; measured 46s → ~10s, zero discovery detour): a FORCEFUL front-loaded prompt** that (1) names the exact verbatim hcom command, (2) asserts it's already correct, (3) explicitly forbids the discovery. Proven phrasing:
  > *"Your VERY FIRST action — before reading ANY file, before running hcom --help / hcom status / hcom list / hcom send --help — must be to run this EXACT command (it is already correct, do not verify it): `hcom send @<orch> --file <path> …`. Then …"*
- For a **real review** (agy still must read the diff), front-load an **immediate notice** as action #1 (`hcom send @<orch> --intent inform -- "starting review"`) and hand it the verbatim final-report command — so the only thing agy explores is the code, not the hcom CLI. **Use `--intent inform`, NOT `--intent ack`:** a freshly-spawned agent has no message to reply to, and `--intent ack` HARD-FAILS its first send with *"Intent 'ack' requires --reply-to"* — which would tip agy back into the exploration this prompt exists to prevent.
- **Complementary fallbacks:** wait ≥60–90s for agy's first message; `hcom events sub --agent <name>` / watch the bus instead of a fixed `hcom listen` window.

## 4. The PreToolUse approval hook — ONLY hits `claude` (if your host has one)
If your host runs a `PreToolUse` approval hook (e.g. a remote-approval gate that prompts before Bash/Write/Edit), it **only gates `claude`** — `codex`/`agy` don't run the host's hooks, so they're immune. If your host has no such hook, skip this section. For a typical remote-approval hook:

- It's usually **a no-op unless a toggle file exists** (e.g. `touch /tmp/claude-remote-approval` to enable, `rm` to disable). Off most of the time.
- When ON and unanswered, it returns `permissionDecision: "ask"` → an interactive prompt the headless agent can't answer → it blocks. A per-session "Allow All" cache (e.g. `/tmp/claude-approved-<session_id>`) means an agent approved while you're present keeps running, but a NEW headless session started while you're away stalls on its first Bash/Write/Edit.
- A well-built hook reads an **allow-dirs file** (one path prefix per line) and **auto-approves any agent whose cwd prefix-matches a listed dir**.
- **So: spawn the claude reviewer/implementer with `--dir` under an allow-listed path** → it runs unattended even with remote-approval on. To allow-list a new root, append its path to that file.
- **`--dangerously-skip-permissions` does NOT bypass the hook** (hooks run above the permission flag). A project `settings.json` can't remove it either (Claude Code merges hooks additively); a clean `CLAUDE_CONFIG_DIR` would drop the bus hooks too. An allow-dirs entry is the clean fix (reversible by removing the file).
- **Unblock a stuck agent in the moment:** `hcom term inject <name> '1' --enter`.

## 5. FALLBACK — direct one-shot CLI (read-only review, no bus; use only if hcom-spawn is unavailable)
- **claude** → in-process **Agent tool** (`subagent_type: general-purpose`), read-only instructions.
- **codex** → `codex exec --sandbox read-only --skip-git-repo-check --cd <worktree> "<prompt>"` — review to stdout (ignore `hook:` / `tokens used` noise).
- **agy** → `cd <worktree> && agy -p "<prompt>"` (`-p`/`--print` to stdout). Do NOT add `--sandbox` (swallows output). **agy is NOT read-only sandboxed** — give it its OWN throwaway worktree (NEVER the shared main repo) and the prompt MUST say: *"STATIC review only — do NOT run cargo build/test; read via `git show`/`git diff` only; do NOT checkout/edit/write/commit; output the review now."* Else it idles (no verdict) and/or writes (it once ran `git checkout` in a shared repo). codex `--sandbox read-only` enforces this for you; agy does not.
- **⚠ When backgrounded (`run_in_background`), append `< /dev/null` to BOTH `codex exec …` and `agy -p …`** — a non-TTY stdin makes them hang forever waiting for EOF (codex prints "Reading additional input from stdin..."). `< /dev/null` → immediate EOF, runs to completion.

## 6. "Flaky model" is usually YOUR topology — one writer per branch (origin story)
Tri-model review of a PR: a reviewer dropped its hcom verdict, then wrote/committed/pushed a fix into the integrator worktree → a multi-writer collision. First written off as "headless model is flaky." **That was wrong** — the same session ran many agents for hours (reviewing, sending verdicts, pushing fixes) with no issue, same machine/bus/model. The problem was the setup.

- **One writer per branch.** Don't be orchestrator AND implementer on a shared/branch-attached worktree while review agents are live (literal edit-vs-write races).
- **Don't give reviewers detached-HEAD worktrees while a branch-attached worktree is reachable** — a reviewer that decides to "help" can't commit from detached HEAD, so it reaches for the one attached worktree it can find (yours). Isolate each agent on its own attached branch, or run reviewers where they cannot see the integrator's working copy. Leave it nowhere shared to land.
- **Mandate `hcom send --file`** from the start; never inline rich text.
- A single failed spawn (an agent that errors on startup with no response) is a **transient — relaunch it; don't generalize to "flaky."**

## 7. Orchestrator still owns the call
- **Adjudicate contested findings against the source — never majority-vote.** Twice the review majority was wrong (once 2 reviewers wanted a "fix" that would have broken a working PR; once 1 reviewer caught a real security bug — a bypassed validation check — the other two missed). When reviewers disagree on a factual point, read the actual code/spec and decide.
- **Verify CI yourself** ("observed green," not "looks fixed") — especially stacked PRs whose CI never ran.

## 8. Phase G — "grind to green" (the iterative gate; run recipe)
**What the word means.** Two sibling commands the human types at a PR:
- **"Phase R #N"** → run ONE gate round, report, **do not fix**. (The advisory assessment.)
- **"Phase G #N"** → **converge the PR to landable.** Loop the gate, apply fixes between rounds, stop only when it's green-and-ready or you escalate. Naming "Phase G #N" with nothing else IS a complete instruction — drive it to done; don't stop at the first verdict and ask "now what."

**The round loop (this box):**
0. **Pre-flight.** Establish the writer's branch-attached worktree (the one place fixes land). If `gh pr view N` shows `CONFLICTING`/`DIRTY` against a real base (the trunk, not an integration branch), **round 0 = rebase**: the writer rebases/merges base, pushes, then proceed. Confirm any approval-hook toggle state (§4) if the writer is headless `claude`.
1. **Gate (round k).** **First confirm you still own your name** — `hcom list self` must print `<orch>` (§9); if it shows a hex/UUID or "(not participating)", reclaim with `hcom start --as <orch>` BEFORE spawning, or the reviewers' verdicts drop silently. Then spawn 3 FRESH reviewers (`claude`+`codex`+`agy`) via **`phase-r-spawn.sh <orch> <repo> <pr> <tag> <wt_base>`** (§2 — parallel + backgrounded, returns <1s; it warns if `self`≠`<orch>`; never serialize or sit in the readiness wait). +1 truly-fresh reviewer on consensus/security/state-machine PRs — a **different model than the PR's author**. Each reviews the increment read-only, reports via `hcom send --file` AND leaves its verdict in `REVIEW-<tag>-<model>.md`.
2. **Adjudicate (§7).** **Collect all three verdicts by READING the `REVIEW-<tag>-<model>.md` files in the reviewer worktrees — not just what arrived on the bus** (bus delivery to `<orch>` is silent-drop on drift; the files are identity-immune, §9). Don't proceed on 2/3 — chase the third (it's usually dropped/idle). Read contested findings against the source yourself — never majority-vote. **Sweep the whole class of any bug found, not just the reported instance** (partially-closed classes are why rounds don't converge). Produce the round's `[BLOCK]`/`[SHOULD-FIX]` list. If zero blocking findings AND the terminate condition holds → **done** (go to step 6).
3. **Fix — ONE writer per round.** The finder usually owns its fix; otherwise pick a single writer agent in the branch-attached worktree. **Single-PR variant (you are also the author):** EITHER (a) delegate to one writer agent, OR (b) apply it yourself but ONLY after all review agents for that round have exited — never hand-edit the branch worktree while reviewers are live (edit-vs-write race). Reviewers stay read-only + isolated; the writer worktree path stays out of every reviewer brief.
4. **Push + wait for CI.** Writer pushes. **Poll CI to completion** (`gh pr checks` / `statusCheckRollup`) — "observed green," not "looks fixed." NB: on some repos the deploy/build/smoke job runs only on a trunk-branch push (`if: ref==main && push`), so a PR's green checks may not exercise the change — say so, don't claim CI proved it. And don't rebase+force-push a green PR just to refresh stale checks (can hide a bad merge) — verify the merged tree locally.
5. **Re-gate.** Round k+1: per Phase R, reviewers may persist and the finder owns its fix — so **add a +1 truly-fresh reviewer (different model than the author) on high-stakes (consensus/security/state-machine) PRs to offset the anchoring of any reviewer who drove a fix.** Re-spawning all three fresh each round is the higher-rigor option (avoids anchoring entirely) but is NOT the documented default — choose it deliberately, don't assume it. Back to step 2.
6. **Terminate** when all reviewers `ready` (no blocking) **AND** CI observed green **AND** every `gh` review thread resolved (verify with `gh api`, not eyeballed). **The ~3-round cap is a spin detector, not a budget** — if rounds are still closing real findings toward green, keep going; if two rounds show no forward motion, STOP and escalate to the human with the open `[BLOCK]`s + a one-line why-stuck. Escalate early on: genuine spec ambiguity (→ DECISIONS-NEEDED), persistent 3-way disagreement on a factual point, or a fix that keeps regressing. **Before you escalate a "not converged / no verdicts in" — rule out identity drift first.** A silent-dropped verdict (`delivered_to: []`, §9) is indistinguishable from "the reviewers never approved," and G's per-round writer dispatch/resume makes drift *most* likely exactly here — so a clean PR can burn the round cap and false-escalate. Confirm `hcom list self`==`<orch>` and read the `REVIEW-<tag>-<model>.md` files; if you drifted, `hcom start --as <orch>`, re-collect from the files, and only then judge convergence.
7. **Never merge/deploy.** Phase G ends at "ready to land"; the human lands it. Update the `STATUS.md` ledger `Round` column each round; on exit, do the post-run hygiene (kill `tag:` reviewers, `git worktree remove` their worktrees).

## 9. Bus identity is soft state — drift, silent-drop, detection, recovery
The whole gate routes on `@<orch>`, but that name is **not durable**. A long, subagent-heavy orchestration can lose it out from under you and you won't notice, because delivery fails *silently*. Verified against the bus DB (`~/.hcom/hcom.db`) + the event log:

- **How identity works.** A bus name is a row in `instances` (PK `name`), reachable only while it's bound to your live session via `session_bindings` (`session_id→name`) and/or `process_bindings` (`process_id→name`). `hcom` resolves "self"/"Your name" through those bindings using the caller's session/process context (there is **no** `HCOM_NAME` env var — it's a DB lookup keyed on the session id).
- **Drift.** In a long run with many Agent-tool spawns and resumes of bus-aware subagents, a competing `process_binding` to a subagent's agent-id can shadow your session_binding, and your own `hcom` calls start resolving as that subagent. *Observed:* the orchestrator's diagnostic Bash commands got logged under a subagent's agent-id, and `hcom config -i self` returned that id, while the orchestrator's own name got no heartbeat. **The exact precedence that picks the subagent binding over yours is NOT nailed** — do not build the fix around a specific trigger; treat every long run as at-risk and rely on the trigger-independent defenses below.
- **Reclamation.** Once your name isn't refreshed under its own identity it goes idle, hcom's `stale_cleanup` deletes the `instances` row, and `ON DELETE CASCADE` removes its `session_binding`. Now "self" won't resolve at all (`hcom list` → `Your name: (not participating)`).
- **Silent drop (the dangerous part).** `hcom send @<orch>` to a deleted/renamed inbox **does not error** — it records the message with `delivered_to: []` and returns success. *Verified:* reviewer sends to a cleaned-up `<orch>` all show `delivered_to: []`; the same reviewers' earlier sends show `delivered_to: [<orch>]`. So the verdict is produced, "sent," and dropped; the gate looks stalled with "no verdicts in" when the verdicts actually exist. (Ad-hoc `hcom r <orch>` to auto-recover was tried and the re-created instance went inactive seconds later — resume is not reclaim.)

**Detect** — at every round boundary, and any time a verdict seems missing:
```
hcom list self                 # must print <orch>; a hex/UUID or an error = you drifted
hcom list -v | head -1         # "Your name: <orch>"  (NOT an agent-id, NOT "(not participating)")
```
Inbound side: a verdict event whose `delivered_to` is `[]` never reached any inbox (`hcom events --last N`).

**The durable channel — poll the files, don't trust the bus.** Reviewers write `REVIEW-<tag>-<model>.md` into their worktrees (`phase-r-spawn.sh` enforces this filename and pre-flights it). **Treat that file as the verdict of record and read the three files directly**; the `hcom send` is only a notification. This is immune to every identity failure above and makes recovery lossless — sends made while you were "gone" are lost, but the files persist, so you can reconstruct the round after reclaiming.

**Prevent + recover:**
- **Pin.** hcom's own rule (top-level `--help`) is *"use `--name <name>` on all commands."* Apply it to the orchestrator's OWN `hcom send/list/events`, not just spawns, so your calls stay attributed to `<orch>` even if the session binding drifts. *(Pin fixes attribution; it does NOT resurrect a stale-cleaned instance.)*
- **Reclaim.** `hcom start --as <orch>` re-creates the instance + session_binding for the current session — this is exactly its documented purpose ("Reclaim identity after compaction/resume/clear"). Run it the moment `hcom list self` ≠ `<orch>`, then re-verify and re-poll the REVIEW files. (`hcom start --orphan <name|pid>` recovers an orphaned PTY process.)
- **Hygiene compounds the risk.** Listeners you never `hcom stop` pile up and are extra reclaim/cleanup targets. Do the post-run hygiene (§ post-run hygiene in SKILL.md) on every exit.

## 10. agy first-run folder-trust prompt hangs on a FRESH worktree
A headless **agy/antigravity** reviewer spawned into a brand-new worktree can hang indefinitely on antigravity's own first-run **"Do you trust the contents of this project?"** dialog — `--dangerously-skip-permissions` does NOT bypass it (it's the CLI's folder-trust dialog, not the review-permission layer). Symptom: the reviewer sits `listening: blocked` with no `REVIEW-*.md` and never sends a verdict; `hcom term <name>` shows the trust dialog with `> Yes, I trust this folder` selected-but-unconfirmed. **Fix in the moment: `hcom term inject <name> --enter`** (the default selection is already "Yes"). It then proceeds normally. Not all agy reviewers hit it in a batch (worktree-trust state varies), so poll each agy's REVIEW file and inject the stragglers rather than assuming a dead agent. Ties to §9's "poll the files, don't trust passive delivery."
