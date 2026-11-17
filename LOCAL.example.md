# LOCAL.md — host overlay for orchestrating-parallel-workstreams (template)

Copy to `LOCAL.md` in this directory (git-ignored) and fill in what applies. The skill reads `LOCAL.md` first if it exists; each heading is a slot the doctrine/runbook otherwise leaves abstract. Delete slots that don't apply.

## Worktree base
- `$WT_BASE` = <dir holding review/writer worktrees, e.g. /home/me/work>; `phase-r-spawn.sh` arg 5.
- Detached inspection worktree: <path, e.g. $WT_BASE/_inspect> (create with `git worktree add --detach <path> <sha>`).

## Approval hook (if the host has one)
- Hook: <path, matcher>; toggle: <file>; per-session allow cache: <file>.
- Allow-dirs file: <path>; already allow-listed: <dirs>.
- A stuck approval prompt is the human's to answer; otherwise respawn the agent under an allow-listed `--dir`.

## External review bot (if the repo runs one)
- Name: <bot>; marker comment: `<!-- … -->`; posts under: <login1>, <login2>.
- Operator: <who> (route build-host problems there, not to the repo owner).
- Automated gate covers: <what invariants/surface — so you can tell "orthogonal" from "blind spot" when it degrades>.

## Landing policy
- Orchestrator lands: <nothing | integration-branch PRs after the writer reports green + light green-check>.
- Human owns: <integration branch downstream — deploy targets, releases>.

## Writer model
- Preferred implementer for consensus/security/state-machine work: <model>; +1-fresh reviewer must then be a different model.

## Gate reviewer model (optional)
- `PHASE_R_CLAUDE_MODEL=<model>` — `phase-r-spawn.sh` passes it as `--model` to every claude reviewer it launches (the trio's claude + extra reviewers). Unset = the CLI default. Mirror it in the runbook §5 in-process fallback (`model:`).

## Extra skill-driven reviewer (optional advisory 4th lens)
- `PHASE_R_EXTRA_REVIEWERS="<label>[=<abs worktree path>] …"` — each label adds one claude reviewer that runs a review SKILL named in its BRIEF.md (a repo's merge-gate skill, a deep-review bot you can run locally) instead of the diff brief. Path default `$WT_BASE/wt-<tag>-<label>`; set it when the skill's tooling keys on the path.
- Per-PR setup: <worktree at PR head, BRIEF, any container/toolchain the skill needs, approval-hook allow-list>.
- Cadence: <every gate | Phase R always + Phase G round 0 and final | opt-in>; wait bound: <minutes> (past it: report pending, never drop).
- Verdict mapping: <skill's verdicts → READY / BLOCK / ESCALATE; what "degraded" means for this skill>.
- BRIEF: see orchestration-templates.md "Skill-driven extra reviewer brief"; keep a cheap plumbing-test variant for acceptance after gate changes.

## Autonomy settings (ask the human once; conservative default applies until answered)
The twelve questions are in `reference/briefs-and-decisions.md`, "Per-host autonomy settings". Record each answer here by number, in the human's words, with the date.
- 1 Decisions during a run: <surface and wait | decide, log, keep moving>
- 2 Starting needed work: <ask first | start and report>
- 3 Follow-ups on the program's own changes: <ask | do and report>
- 4 Honouring a constraint just stated: <ask | act and report>
- 5 Landing authority: <orchestrator lands nothing | lands integration-branch changes under <checks>>
- 6 Replying to review bots: <per-reply approval | standing-authorised>
- 7 Stacked changes: <default | forbidden>
- 8 Gating trivial changes: <always full gate | classes that may skip: …>
- 9 Threat model default: <adversarial | trusted-colleague tools>
- 10 Other people's changes: <never touch | …>
- 11 Trackers and chat: <draft only | may post>
- 12 Where tests run: <CI full, local targeted | local full first>

## Forge
- Code host: <GitHub | GitLab (gitlab.com | self-hosted URL) | other>; CLI: <gh | glab>; logged in as <account>.
- If not GitHub: `PHASE_R_DIFF_CMD="<e.g. glab mr diff <mr> -R <group/project>>"` in the shell that runs the gate, and use the runbook §13 command map.
- Merge method the project allows: <merge commit | squash | fast-forward only>; does a push reset approvals? <yes/no>.

## Repo CI quirks
- <repo>: <e.g. deploy/build/smoke job runs only on trunk push — PR checks may not exercise the change>.
- <repo>: <e.g. tests behind non-default feature `X`; sub-workspace `Y/` excluded from `--workspace`>.
