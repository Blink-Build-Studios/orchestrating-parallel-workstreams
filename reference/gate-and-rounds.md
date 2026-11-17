# Gate and rounds

Read this when you are about to set up a review gate, write a round list, or decide whether another round is worth running. It adds to SKILL.md "Phase R" / "Phase G"; it does not repeat them.

## Pinning the gate to a head

**Assert, in the spawn step itself, that the forge's head for the change equals `git rev-parse HEAD` in every review worktree, and print that SHA in every brief.** A gate is valid only for the exact head the worktrees sit at, and the head can move between the writer's report and your spawn. One gate launched on a stale head cost five reviewer seats and a rebuild of every worktree.

**Require every review file to state the head its evidence was produced on, and check each worktree's HEAD again before landing.** A launcher that creates worktrees "only when absent" silently reuses the previous round's checkout when a tag is reused; anyone who built or tested there produced evidence for the wrong tree, and nothing in the verdict shows it.

**Use a new tag for every round (for example `<repo>-<change>-r<k>`), and archive each round's `REVIEW-*` files before the next dispatch.** A new tag gives the round its own worktrees and verdict paths; a reused tag leaves last round's verdict at the path you poll for this round's. Never put two agents in one worktree; that breaks write isolation. To keep build caches warm (a cold deep-review build can cost hours per round), give every round's reviewers a shared build-cache directory instead of reusing a worktree. Remove a round's worktrees once its review files are archived and its agents are closed.

**Never check out a new head under a reviewer that is still running.** A deep reviewer re-reads source throughout its run, so swapping the checkout makes its later reads inconsistent with its earlier ones and silently corrupts the verdict. Let it finish on the old head, then delta-check its verdict against the new one; the new head is a new round with its own tag and worktrees.

**Allow one executing lineage per checkout.** A forked or sub-spawned reviewer inherits its parent's working directory; if both run mutation tests there, each sees the other's half-applied edits and reports wrong passes and wrong failures. Briefs for executing reviewers say: run every mutation in a throwaway worktree you create at the gated SHA; a parent that forks only collates.

**When the change is mergeable but behind its base, point reviewers at a preview merge commit.** Build it with zero side effects (`git merge-tree --write-tree` then `git commit-tree` with both parents, tagged locally; git 2.38+). `git merge-tree` exits 1 on a conflict and still prints a tree: stop there, the change is not mergeable. Name the tag and SHA in every brief, and delete the tag in post-run hygiene. "Mergeable" only says the text merges; base-side commits can change what the head's code requires, and reviewers at the bare head never see that.

**Launch gates from a script that does not depend on the current directory, and give every reviewer its own scratch directory.** Spawns fired from the wrong cwd came up without a brief. In-process subagents share the orchestrator's scratchpad, and one overwrote the orchestrator's script with a same-named file of its own.

**Check that the spawn prompt and the brief agree about execution.** If the launcher's default prompt says "static review only" and the brief says "you must run test X", the reviewer blocks procedurally or skips the run. Route execution to a lane whose prompt allows builds, or authorise it explicitly after spawn.

**Do not brief reviewers to route every build through a sandbox wrapper without carving out what the wrapper breaks.** Tests that need real mounts, real path ancestry or child processes fail en masse inside a private namespace, and the gate reports hundreds of false failures against sound code.

## What goes in the review brief

**Refresh a stale change description, or put the decision trail in the brief, before gating.** Reviewers read the description as the statement of intent; if it describes an older design they spend the round relitigating what was already settled.

**Give reviewers every file the rules under review cite.** A review pack that names a spec or a validator without including it gets verification by name only.

**Ask whether every premise of the change's safety argument exists at the reviewed head.** "This is safe because check Y rejects it" is void when Y lives on an unmerged sibling branch. Likewise, if the change fails open unless another change is already live, record merge order as a correctness constraint on the status board.

**When a change stamps or rewrites a field of a validated wire envelope, task one reviewer to read the pinned validator's whole constraint set and require a default-run test that passes the changed envelope through that validator.** Five reviewers and the orchestrator once traced how the field was encoded and stopped; the constraint lived in a different function, and tests that bypassed the ingress path stayed green. State it as a class ("every rule the validator applies to this envelope"), not as a check on the one field.

**For a frozen foundation contract, ask "what carries this?"** Freezing the types is not enough; the endpoint, message or call that puts the new type on the wire has to be in the frozen set, and the plan has to list every consumer repo.

**When a change edits the source of a committed generated artifact, make "was it regenerated?" a check item.** A stale binding, compiled blob or golden masks the change until a downstream consumer breaks.

**For any change on a deploy or dispatch path, require the assembled payload to be measured at the head against the transport's documented size limit, with a CI test that fails below the hard limit.** A dry run that skips the transport proves nothing about the transport; one fully approved change died on its first real deploy because the payload had quietly crossed the limit.

**When a design stores or consumes a paid credential in shared infrastructure, put the ownership question in the brief.** Whose account does it bill, who can overwrite it, and does the interface invite a personal credential into a shared slot? Mechanism-focused reviewers will check access control and never ask.

**On a change that edits CI, ask which steps run code from the change's own checkout with an organisation secret in scope.** Every script in such a job is controlled by the change, so "fetch only" or "helper-validated" steps are still exfiltration paths; the durable rule is no organisation secret in any step that runs untrusted merge-request code.

**Never brief reviewers with an absolute security claim.** "Never on any path" makes every conceivable bypass a blocker and the loop unbounded. Write the guarantee against the threat model stated in the brief (for example "for honest use", where `LOCAL.md` autonomy item 9 says so), say what is out of scope, and let that bound the round.

## Round content

**Sort every report into two buckets before writing the round list: confirmed blockers, and everything else.** A blocker is a defect with a trigger, a security bypass, a fail-open guard, or a false-green test. Everything else gets a follow-up ticket and a reply saying so. File and post them yourself where `LOCAL.md` (autonomy items 6 and 11) allows it; otherwise draft them for the human. Do this before sending the list. Advisory churn took two changes past ten rounds each, at an hour or more of CI per round. Reviewers keep reporting everything; the filter is yours.

**Fold an advisory item into a fix round only when it is minutes of work in a file already open for a blocker, and say that you did.** Each folded note grows the diff, and grown diffs produce new defects.

**After round 0, send increment briefs that carry a "deferred, do not re-raise" list and require every new test to be shown red on the old head.** Without the list, fresh reviewers rediscover the deferred items; without red-on-old, a new test may pin nothing.

**Never hold a push waiting for the previous round's extra skill-driven reviewer** (it is outside the 3/3 quorum). Decide at launch which rounds it runs in, then let pushes proceed; its late verdict is triaged against the newer head. This never applies to a trio reviewer: a round is not judged without all three. Holding every push made each one cost a full deep-review cycle.

**Under deadline pressure, do not offer to weaken the gate or defer real findings.** Shortcuts move risk rather than remove it. Gain time through parallelism (briefs and launch scripts prepared ahead, pushes timed with verdicts), fewer errors of your own, and tighter class-closing rounds; report the honest ETA.

## Sweeping the class

**Sweep by behaviour, not by identifier name, and across every build workspace in the repo.** A name-based sweep missed two tests that exercised the behaviour without naming the constant, in a sub-workspace the default build excludes.

**Write acceptance greps repo-wide and require the writer to paste the empty output.** A grep scoped to the file the finding was in closed ten sites there and left the same helper in the neighbouring file, costing another round.

**When a round item names a class over a decision enum, enumerate every arm in the confirm brief and require one test per arm.** A writer closed one refusal arm, left its sibling, and wrote a test that blessed the sibling's wrong behaviour. A test asserting that a drop or rejection "succeeded" deserves a second look against the class statement.

**When a fix generalises, check that the general rule still covers each specific case it replaces; when a fix introduces a mechanism, sweep the mechanism's own instances in the same round.** Generalising one ban re-allowed the thing it banned; a cursor added to fix one stranding bug carried the same bug one level down.

**Build a census of call sites from the call graph, not from a grep for names.** Start at the roots, follow wrappers to a fixed point, then classify terminals; have the document state the method rather than a count. A grep-built list was wrong three times.

## Knowing when to stop

**Propose cutting an item that has not converged after two rounds: revert it to base and file it, with the human's go or under a `LOCAL.md` autonomy grant.** Two rounds without convergence means the item is under-designed, not under-reviewed. Absent the go or the grant, escalate it as a decision and leave the item as it is.

**When the second round on an enumerating guard finds a sibling of the first bypass, stop patching the pattern and rule the structural form.** A deny-list can never be complete against someone who reads it. Allow only what equals a reviewed template, scope the protected thing so nothing unlisted can reach it, and parse syntax instead of matching spellings; one guard lost five rounds, one sibling at a time, before this was done.

**End a fix loop on the finding that the surface is an unbounded equivalence class, not on a round count.** If several fail-closed patches in a row each open a new reachable hole on the same surface, split that surface out of the change and solve it where it is structurally tractable. If stage-by-stage fixes keep arriving with no target architecture, write one before the next change.

**To break a reviewer split, first check whether the alleged regression is already the merged status quo.** If it is, the finding belongs to whichever change owns that behaviour, not to this one; reassign it. This is the cheapest way to break a split.

**When reviewers agree on the facts and differ only on gating philosophy, stop and hand the human a decision with the follow-up tickets drafted.** "A strict improvement over what is deployed" versus "it newly leans on a pre-existing gap" is a policy call; another round will not move it.

**In an advisory gate on someone else's change, escalate for an author fix pass when a round's delta is hygiene-only and the headline blocker has not moved.** Further rounds only re-confirm what every reviewer already said.

## Gating a composed tree

**Per-change convergence is not sufficient for a set of dependent changes: merge the approved heads into an integration branch and run the full gate, plus any external reviewer, on the composed tree.** Cross-change interactions are where defects kept appearing after every individual change was approved.

**Keep sweeping the external review bot on the composed change after every merge into it, on a cadence, until it lands.** Such bots re-review the integration change on each merge, often hours late; dozens of findings, some severe, once sat untriaged because polling stopped at per-change convergence.

**Make "list every bot review and confirm each finding has a posted reply (or a drafted one, per `LOCAL.md`)" a fixed step of every gate launch and every landing check, across all heads.** Page through the full comment listing and key on comment id (a long thread exceeds one page and the newest review is the one missed); also read inline discussion threads, since some bots post nowhere else; do not infer "no review" from a missing check entry; and keep polling after the merge, because bots review final heads late.

## Document and plan gates

**For a gate on a proposal, spec or strategy document, skip code-oriented extra reviewers and build a primary-source research pack first.** Save sources with URL and retrieval time, place the pack inside each reviewer's worktree (a reviewer forbidden to read outside its worktree cannot follow a path elsewhere), and tell reviewers the pack's summaries are leads to re-verify against the raw files. On one proposal the pack decided the review: the draft targeted a retired rubric and misquoted its own reference.

**Have reviewers write the verdict file first, and make any model known to invent citations paste the search output behind each one.** Adjudicate every finding against the source before touching the document; a plan edited on an unverified finding carries the fabrication forward.

**Bound document rounds and move leftovers to a residual list.** Every polish round on a design document surfaces one or two new should-fix items, forever. Stop when a round finds only gaps in the text the previous round added, and hand the residual list to the implementation plan.

**Schedule a code-grounded round before calling a spec gate terminal.** A review of the spec alone misses gaps that a design review against the code finds. Wording-only rounds can drop to a single independent reviewer.

**Before gating changes taken over from another team, map them against the governing design document: built, partial, deviating, missing.** The inherited changes may not cover the design, and a gate only reviews what is in front of it.
