# Landing and integration

Read this when an approved change has to be rebased, merged with a moved base, pushed, held, or landed — or when you are planning how several repos converge. The orchestrator still does not merge or deploy unless `LOCAL.md` grants it; these rules also shape what you tell the human who does.

## Rebases and moved bases

**After any non-mechanical rebase of an approved branch, confirm with a per-file diff-of-diffs and a by-name search for every regression test from earlier rounds.** For each owned file compare `git diff OLD_BASE..OLD_HEAD -- f` with `git diff NEW_BASE..NEW_HEAD -- f` and classify each differing hunk as "now owned by the base" or "re-applied". A rebase can drop approved hunks with no conflict marker surviving: one replayed commit kept 13 of 313 lines in a file, and two approved fixes and a regression test vanished. Reviewers re-checking only the increment do not see it. Never rename an approved regression test, or the search cannot find it.

**When trunk moves under approved changes, take a merge commit of trunk instead of a rebase and force-push, and prove the merge mechanical.** If the merged tree equals git's own auto-merge of the two parents, the existing approvals stand on content; only a non-mechanical merge needs a re-gate of the resolution.

**When a dependency lands on the base mid-gate, merge the base in, gate the merge resolution, and confirm the change's derived values are unchanged before landing anything that cites them.** One such merge also surfaced a defect in the dependency itself.

**Every rebase re-confirm, even a "light" one, runs the full suites of every package the series touches, in an executing review lane and not by the writer alone.** A focused subset and a commit-by-commit range comparison both showed clean while the full suite had a failure. Also search the series for string-based source guards (a test that asserts some file contains a name) and check each target against the new base: a byte-identical carry-forward cannot surface a base-side rename.

**Announce a shared branch as a rebase target only after its owner has run, at that exact head, the same full test expression CI runs.** Focused tests prove the owner's change, not the composition. Six writers once spent an hour rebasing onto a head that could not pass CI.

**After each merge into the integration branch, verify the new tip.** CI ran on the change's head, not on the merged tree, so two individually green changes can compose red and no gate sees it. The exception: when the change's merge-base equals the target tip at merge time, the head CI already tested the merged tree. The final landing runs the full set on the exact merged tree.

**When CI does not start after a push, check whether the change conflicts with its base before suspecting the pipeline.** A forge that cannot build the merge result may create no pipeline at all, and an empty commit does not help. On a busy base, expect to merge the base in more than once during a long gate.

## Resolving conflicts

**Never resolve conflicts by deleting markers and keeping both sides blindly.** A blind union truncated code mid-statement and broke an integration base. Start from the base side of each conflicted file and re-apply every addition from the other side deliberately (list them with `git diff <merge-base> <other> -- <file>`); never take one side and stop (see tool-quirks/git-worktrees.md). Conflict resolution is writing: hand it to a writer.

**"Keep both sides" is unsafe when both sides insert functions that share a prefix.** Git factors out the common lines and the two bodies fuse into one. Rebuild each function from its own side and compile-check before calling the merge resolved.

## Squash, merge commit or fast-forward

**If dependents pin a reviewed SHA of a foundation change, land the foundation with a merge commit.** A squash orphans the pinned SHA and forces a re-pin, and a CI round, in every consumer. Where nothing pins the head, squash is fine and keeps history clean.

**A change whose content is a merge of trunk into the integration branch lands as a fast-forward of the reviewed head, never as a squash.** A squash has one parent, so trunk's commits never become ancestors of the integration branch; the next integration-to-trunk merge uses the old merge-base and re-derives every conflict the sync already resolved (29 files, once). Before merging into an integration branch, ask whether the head contains a merge commit with a trunk parent. To repair an accidental squash, add a tree-identical ancestry merge on the current tip and verify both diffs are empty.

**Squash-landing an integration branch leaves its history off trunk.** Later work based on that branch has to be re-opened against trunk. Run trunk's landing-only static gates against the integration branch before queueing it, so they do not fail for the first time at the landing.

**Find out what your forge does to a child change when its parent's branch merges or is deleted, and retarget children to their final base before merging the parent.** A child merged into a stack branch shows as merged, cannot be reopened, and has to be re-landed.

**File ownership between stacked workstreams protects production logic only.** A test oracle in the base workstream's file that moves because the dependent changed behaviour is the dependent's to fix, listed explicitly for the confirm round, and never fixed by weakening the check.

## Shared branches with humans

These apply only where the author or the human has allowed work on their branch (`LOCAL.md` autonomy item 10); the default is to leave other people's branches alone. A writer, not the orchestrator, makes the commit.

**When a writer fixes a colleague's branch, it gates the commit locally first, pushes one squashed commit only when it is green, and the author is told.** Never iterate commits on someone else's branch.

**Fetch and compare the remote head before every push to a branch a human is active on.** If the author pushed first, their version wins: archive yours under a local tag and re-gate on their head.

**A fix change stacked on another author's active branch is orphaned when they force-push or squash.** Get it folded in quickly, or retarget it to trunk.

**If the forge requires approval after the last push, an agent pushing under the human's credentials voids that human's own approval.** Have the author push the final fix round, or line up a third approver before the last push.

## Push and landing approvals

**A push approval names the exact head SHA, is lease-protected, and is one-shot — including the first push of a new branch.** Approve `git push --force-with-lease=<branch>:<remote-sha> origin <head-sha>:refs/heads/<branch>`, or for a new branch `git push --force-with-lease=<branch>: origin <head-sha>:refs/heads/<branch>` (the empty expected value means the branch must not exist yet), plus "this approval is consumed by this single run". A writer replayed an earlier approved bare `push <branch>` for a later, unverified head; a SHA-bound, leased form cannot be replayed.

**A pre-authorisation to land covers only the list given at the time, and only the exact gated head of each item.** Get new landings authorised before the human steps away. Pass the gated SHA to the merge command so the forge refuses if the head moved.

**A scripted pre-merge guard must make the merge command itself conditional on the check.** A guard that printed "abort" and then ran the merge on the next line merged anyway. Distinguish a failing required check from a non-required advisory check that merely renders as "fail".

## Config before merge on auto-deploying branches

**When a brief adds a required runtime config value, find out whether the target branch auto-deploys, and name that in the brief.** Where merge is deploy, a required-config change is a two-repo change with an ordering constraint. One fail-closed check went live at merge with its variable unset and refused requests behind a generic error until the configuration caught up.

**The infrastructure change lands and is verified in the running environment before the push signal — or the code defaults to the previous behaviour until configured.** Use the default only where failing open is safe.

**Have one reviewer answer "what happens in the deployed environment where this value is unset?", and require the failure to surface as a specific, visible message.** The local rig sets the value, so the unset case is otherwise never exercised.

**The deploy runbook lists each config value with its currently deployed value, never "unknown".** An "unknown" is the unset value that fails closed at merge, and whoever deploys cannot check what the runbook does not state.

## Long holds

**State the cost of a hold up front, and recommend freeze-and-land over chasing trunk.** A large set of gate-passed changes held unmerged decays: repeated catch-up merges and re-gates, pins moved by other programs, and eventually a teammate re-lands the same content as new commits.

**Measure an integration branch's mergeability against trunk on a schedule with a dry-run merge.** Conflicts in pinned or derived values cannot be resolved from a diff and are hard blockers on the final landing; on one program nobody measured until the day before.

**When trunk moves hourly, tell the human to land a green change immediately.** One change needed four rebases while it waited.

## Topology acceptance

**A master plan for two or more repos includes, from the start, a production-topology acceptance workstream, a deploy-and-convergence workstream, and a seam list.** The acceptance run drives the real front door end to end; the convergence workstream owns pins, manifests and the runbook; the seam list names every hop between repos with its auth and identity mapping, and is re-checked at every ruling that touches identity. Per-repo workstreams assign the seams to no one: every change in one program passed a four-reviewer gate while the production gateway had no route to the new endpoints and signed as a different identity than the tests did.

**An acceptance proof must drive the path production uses, not a convenient client or a privileged test identity.** An acceptance run on the real topology found a durability bug four review rounds had missed, because the proof test went through the SDK instead.

**Re-check every repo's pins before declaring "one revision everywhere".** Other programs move them.
