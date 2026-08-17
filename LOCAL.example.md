# LOCAL.md — host overlay for orchestrating-parallel-workstreams (template)

Copy to `LOCAL.md` in this directory (git-ignored) and fill in what applies. The skill reads `LOCAL.md` first if it exists; each heading is a slot the doctrine/runbook otherwise leaves abstract. Delete slots that don't apply.

## Worktree base
- `$WT_BASE` = <dir holding review/writer worktrees, e.g. /home/me/work>; `phase-r-spawn.sh` arg 5.
- Detached inspection worktree: <path, e.g. $WT_BASE/_inspect> (create with `git worktree add --detach <path> <sha>`).

## Approval hook (if the host has one)
- Hook: <path, matcher>; toggle: <file>; per-session allow cache: <file>.
- Allow-dirs file: <path>; already allow-listed: <dirs>.
- Unblock a stuck agent now: <command>.

## External review bot (if the repo runs one)
- Name: <bot>; marker comment: `<!-- … -->`; posts under: <login1>, <login2>.
- Operator: <who> (route build-host problems there, not to the repo owner).
- Automated gate covers: <what invariants/surface — so you can tell "orthogonal" from "blind spot" when it degrades>.

## Landing policy
- Orchestrator lands: <nothing | integration-branch PRs after the writer reports green + light green-check>.
- Human owns: <integration branch downstream — deploy targets, releases>.

## Writer model
- Preferred implementer for consensus/security/state-machine work: <model>; +1-fresh reviewer must then be a different model.

## Repo CI quirks
- <repo>: <e.g. deploy/build/smoke job runs only on trunk push — PR checks may not exercise the change>.
- <repo>: <e.g. tests behind non-default feature `X`; sub-workspace `Y/` excluded from `--workspace`>.
