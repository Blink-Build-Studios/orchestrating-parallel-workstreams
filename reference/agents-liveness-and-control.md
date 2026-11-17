# Agents: liveness and control

Read this when agents are running and you are deciding whether one is working, stuck or finished — and before any pause, handoff, or write to the tracker. It assumes the watcher-plus-heartbeat rule in SKILL.md "Quick reference".

## Classifying agent state

**On every poll, classify each agent from four signals, not from the bus roster.** The signals: durable output (report and work-file modification times, commits, pushed heads); process CPU time advancing across the agent's process tree; the terminal screen (a working indicator versus an empty prompt); and known banners (capacity or session limit, network error, folder-trust prompt, security modal, refusal, approval prompt). A stalled agent looks like a thinking agent on the roster, and orchestrators have lost dozens of hours to that.

**Apply a fixed remedy per class and log each classification.**
- Productive (any of output, CPU or screen advancing): leave it alone, however long it runs.
- Stalled (idle prompt, no deliverable, CPU flat on two checks 30 seconds apart): inject a resume line into its terminal; a bus message alone does not wake every tool.
- Banner: apply that banner's specific remedy.
- Hung (working indicator showing, but CPU and files flat for 20 minutes): treat as stalled.
- Dead: resume it; otherwise respawn in the same worktree.

**Never nudge or time-box a reviewer that is still working.** The slow reviewer is often the one going deepest, and a rushed verdict throws away the dissent the gate exists to catch. Nudge only idle, stalled or blocked agents; tell the human "still running" and re-arm the watcher. A wait bound changes how you report the verdict (*pending*); it never stops the reviewer.

**Treat "listening" with an old state age, typed-but-unsent prompt text, or a dialog on screen as dead, not slow.** One reviewer sat for eight hours behind a feedback dialog and was tallied "pending" for three rounds. Look at the screen of every lane still listening two minutes after a dispatch, and check state age at every round tally.

**Read the review file before calling a verdict missing, and the screen before calling an agent slow.** Agents finish and skip the final send; agents also stop silently when the account's usage limit hits, showing as idle with no file.

## Open asks and missed reports

**Whenever a writer shows idle, listening or stale, read its last few sent messages directly from the bus's event log.** Reports arrive inside hook output that gets truncated or diverted to a file, and a writer waiting on you looks identical to one mid-task. Two writers each sat thirty minutes waiting for a push signal that was owed; one blocked request sat fifteen hours.

**Before ending any turn with live writers, run one pass for unanswered requests and blockers from every writer.** Do this every time, not only when someone looks idle, and never close a session with an unanswered request.

**Have the watcher keep an open-ask list.** Every message to you that asks something and has no later reply from you to that sender is printed on every wake and re-wakes you until answered. Message previews show head and tail, because the ask is usually at the end. After a context compaction, re-list open asks before anything else.

**Send briefs through a guard that refuses suspiciously small files, and write them with the file tool, not a shell heredoc.** A heredoc cut off mid-brief sent a hundred-byte file; the writer asked for a resend, nothing flagged it, and it idled for fifty minutes.

**Never end a phase on a blocking question dialog.** It freezes the turn loop, so no watcher wake or bus message is handled; one orchestrator sat seventeen hours that way while its program was taken over. Write the ask as plain text with numbered options, log it under decisions-needed, keep the watcher armed, and end the turn.

**Chase an unclaimed ask to another team within hours.** An unanswered request sat two and a half days until the human asked why.

## Closing agents

**Close each agent as soon as its own work is done, not at the end of the run.** A reviewer is done when its verdict is collected and it is not kept for the next round (the finder that owns a fix stays until the fix is pushed); a writer is done when its change has merged with no follow-up. Finished agents hold memory, clutter the roster, confuse liveness checks, and keep their worktrees off-limits to disk reclaim. Confirm the output is on disk or pushed, record the closure with time and reason, and sweep at each heartbeat.

**When a writer finishes, record its resume handle and keep its worktree until the change merges.** A late finding or a base move is cheap to hand back to the same writer in the same tree, and expensive to re-brief from nothing.

**Any reclaimer that decides from a liveness query must treat "no answer" as "everything is live", and match liveness by agent name, not by path.** A transient empty result made every worktree look unbound and deleted active build output; an agent's reported directory is its current cwd, which is often a subdirectory of the worktree you are trying to protect.

## Containment

**Every reviewer and writer prompt forbids cloud CLI and SDK calls with any profile.** An autonomous agent uses whatever credentials it finds, and an infrastructure change invites "let me check live". One reviewer tried every credential profile it could find on the box, including one for an account unrelated to the work. Live evidence comes from hosted CI output or the human runs it. Do not leave ambient cloud credentials resolvable on the agent box at all.

**"Read-only" in a brief is not enough for a shared checkout.** Any brief that names a checkout the agent does not own says: read it only through git (`git show`, or `git archive` into a scratch copy), and run nothing inside it — no scripts, generators, tests or builds. A reviewer once regenerated a fixture in place in the human's own checkout. After each gate, check that checkout's status and back up any stray change before reverting it.

**Before any destructive operation on shared infrastructure, confirm exactly one agent owns the execution.** Authorising two agents for the same wipe nearly ran it twice. It is the one-writer rule applied to operations.

**Never edit a shared script in place while agents may be running it.** The shell reads a script incrementally from its open file, so a rewrite makes a running instance resume at a shifted offset; a three-hour gate died that way. Write a new file, syntax-check it, and rename it over the original.

**Before assuming you direct a writer, read the writer's transcript for who is sending it instructions; hand ownership between orchestrators with an explicit, confirmed message.** Two orchestrators were instructing the same writers.

**Two orchestrated programs on the same repos agree on one integration line and stay out of each other's tags and worktrees.** On one box they also share model rate limits and spawn locks, which fail both at once; budget for it.

## Pause, resume and handoff

**When usage is nearly exhausted, broadcast a pause rather than letting agents die mid-edit.** Each writer finishes its current edit, makes a local checkpoint commit without pushing, reports the SHA and a two-line state, and stops. Long-running reviewers write a degraded checkpoint verdict (completed stages, what is pending) and overwrite it when done. Resume each from a staged per-writer list. Done this way, every worktree resumed with zero rework.

**After an account-wide limit resets, check verdict files first, then recover lane by lane.** A shared-account limit stops every lane of that provider at once. A lane may have finished writing before the limit; only lanes with outstanding work need a recovery prompt (re-check on-disk state, redo only what did not complete, send the report).

**Keep the tracker's next-steps section current at all times; it is the only handoff that survives.** A headless orchestrator may not be resumable after a limit, and its agents keep sending to a name that silently drops. Recovery is: reclaim your identity, check disk, write a resume brief pointing at the tracker and decision files and listing live agent names, and have the new orchestrator tell every live agent its name.

**When your context is nearly full, write a handoff document plus a paste-ready kickoff prompt and continue in a fresh session.** A good handoff is a start-here file (restart checklist, capacity budget, flow, lessons), writer briefs that do not name a particular orchestrator, and partial work salvaged as patches against a named base.

**Anything a later session needs goes to a durable directory at the moment it is written.** Reports, scripts and resume notes left in the session scratchpad vanish with the session; this has recurred across half a dozen programs.

## Never log state from a report

**Check the forge before logging a merge, dispatching onto a branch, or trusting a board row.** Read the merged timestamp and the change's state by head branch; read a branch's log before moving its pointer. Three incidents: a false "merged", a false "not merged" from API lag, and a re-dispatch onto a branch that had already merged.

**A tracker status is not evidence.** A ticket marked done had no branch, change or commit behind it. Look for the artifact before relying on "done" or relaying it.

**Re-check live state before repeating a claim to the human.** "This awaits you", "blocked on X", "they have not answered": each has been stale when repeated, sending the human to nudge people about work already finished.

**Never type a timestamp or an ETA from feel.** Read the clock in the same shell call that writes any tracker time, reconstruct past times from event-log timestamps, compute wait bounds from real times, and base ETAs on measured durations. Narrative time has drifted hours fast over a long session, producing a false "past its wait bound" call on a reviewer sixteen minutes in and inflated ETAs the human made decisions on. Convert tool output to the human's time zone before quoting it.
