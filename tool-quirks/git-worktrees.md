# git and worktree quirks

Read this when an agent on this tool misbehaves, or before spawning it for the first time on a new box. Tool behaviour goes stale: every entry carries the date it was last observed; re-check against `--help` before relying on one.

Forge-neutral git behaviour plus the worktree traps of running many agents on one box. The detached inspection worktree rule is in the runbook (§12).

## Costliest first

**A reviewer's evidence does not match the head under review.** A launcher that creates gate worktrees "only when absent" finds the previous round's under a reused tag, still at that round's head, and a seat that sat at a dialog starts from a stale pin. Use a new tag, and so new worktrees, for every round (gate-and-rounds.md), each created at the gated head; fail loudly if `git -C <wt> rev-parse HEAD` is not the gated head for every seat, before spawning and again before calling a round; require each review file to state the head its evidence was produced on. A detached review worktree is acceptable only while no branch-attached worktree is reachable from the reviewer (runbook §6). _(observed 2026-09; unverified)_

**An agent reports "something else is editing my worktree"; mutation or build results flip between runs.** A forked agent inherits its parent's checkout, so two lineages are editing and building in one tree. One executing lineage per checkout: briefs for executing reviewers say to run every mutation in a throwaway worktree (`git worktree add --detach <path> <sha>`), and a parent that forks only collates. Look for a same-directory pair with `hcom list --format '{name} {directory}'` before suspecting another workstream. _(observed 2026-09; unverified)_

**A disk reclaimer deleted build output from under a running agent.** The bus's directory field is the agent's current shell cwd (often a subdirectory), not its worktree root, and a transient empty roster makes every worktree look unowned. Match liveness by agent-name prefix, never by path equality, and treat "no answer" from the liveness query as "everything is live". _(observed 2026-09; unverified)_

**After a branch-reconcile merge, the next sync shows conflicts in files that are byte-identical on both sides.** The reconcile was squash-merged, which drops the other branch as a parent, so git re-derives the divergence. Land ancestry-restoring changes so the source stays a parent: fast-forward the reviewed head (reference/landing-and-integration.md), or use a forge merge commit; never squash. Say so in the title because the forge's merge UI may default to squash; verify with `git log -1 --format=%P <target>` (two parents) right after. Repair after a squash: a zero-tree-change merge of the source into the target. _(observed 2026-08; unverified)_

## Other symptoms

**A new gate fails with "reference is not a tree", or an old gate's brief is overwritten.** The tag was already used, so the launcher reused worktrees and brief files belonging to another round or repo. Before writing a brief, check that no brief, worktree or review file with that tag exists, and use self-describing tags (repo, change number and round), never one that was used before. _(observed 2026-10; unverified)_

**You are reviewing an old head after the writer force-pushed.** A quiet fetch of a review ref into a local tracking ref is rejected as non-fast-forward with no visible error. Use `git fetch --force` (or a `+` refspec), prefer fetching the branch ref over the forge's per-request ref, which can lag after a restack, and compare `git rev-parse` with the head the forge reports. _(observed 2026-10; unverified)_

**A push "succeeded" but the review request did not move.** `git push origin HEAD:<branch>` with a mistyped name silently creates a new remote branch. Read the request's head branch name from the forge first and paste it. _(observed 2026-08; unverified)_

**A merge resolution compiles as text but drops fields or functions the other side added.** A whole-file take-one-side (`git checkout --ours/--theirs <file>`) discards non-conflicting additions in regions the kept side never touched. Resolve hunk by hunk and build the merged tree before pushing. _(observed 2026-07; unverified)_

**An older review mirror stops working after you delete a previous round's.** Per-round mirrors made as shared clones borrow objects from the earlier rounds' stores. Keep the whole chain until the series is done, or clone without sharing. _(observed 2026-11; unverified)_
