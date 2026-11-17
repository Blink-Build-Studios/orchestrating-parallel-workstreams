# Briefs and decisions

Read this when you are writing a writer brief or a fix list, about to record or re-open a decision, or reporting what a plan covers. It adds to the templates in orchestration-templates.md.

## Writer and fix briefs

**State in every writer brief and round list who runs the review gate.** Write "after your push, the orchestrator spawns the reviewers in separate worktrees; you never launch review agents." An autonomous writer treats every imperative-looking line as its own task: a bare "confirm = model A + model B" was executed by the writer, producing anchored reviewers with write access to its worktree and an unrequested transmission to an outside service.

**Put only the writer's own steps in a fix list, with absolute paths.** A writer tried to execute an orchestrator command left at the end of its list, and writers cannot find bare filenames.

**Write fix instructions as exact, testable rules.** Enumerate every case and which side of each boundary, anchor each rule to the code that makes it work, and require one test per rule. Ask "could a careful writer implement this two different ways?" — if yes, enumerate. Two blockers on one change came from the orchestrator's own loose paraphrase, each costing hours.

**Prefer the reviewer's anchored fix over your summary of it; when two reviewers prescribe different fixes, take the one anchored to the code path.** Your paraphrase was written in minutes without their trace.

**Say exactly which code a rule applies to; never issue a blanket ban.** Writers apply fix-list wording literally, including to code you did not mean.

**When a blocker needs a design choice, prefer the fix that removes or narrows a mechanism over one that adds an exception or a guard.** State the chosen rule as a one-sentence invariant and let the writer place it; check any shape rule you prescribe against the real artifact first. Rules invented in fix briefs are a leading source of new blockers: across one long gate, four blocking classes came from the briefs, and each was fixed by deleting the mechanism.

**Name the exact non-default test sweep and its invocation, and require the writer to report which non-default tests ran before pushing.** "The X suite must be green" is read as "whatever runs by default". Five reviewers and the orchestrator missed a defect that only the opt-in sweep caught.

**When CI is slow, treat it as a one-shot confirmation.** The writer passes format, the whole-workspace check and the CI test invocation locally before every push. Whether this box prefers local or hosted runs is a `LOCAL.md` value.

**Tell every writer: fetch first, then branch from the remote base.** Never branch from a local checkout; they run far behind, and work anchored there is anchored to a base that no longer exists.

**Copy specs into the briefs directory.** Headless writers cannot fetch private web documents, and a brief that links one is a brief without it.

**Change titles and bodies, tickets and commit messages must make sense to a reader who has never seen the orchestration.** No bus names, workstream ids, decision labels, plan links, local paths, or names for the internal gate. Explain what the shorthand meant rather than deleting it ("Option A" becomes a paragraph on why this change migrates only some cases). Check the templates you hand writers: one `_common` file required the very residue the human then objected to.

**Label a cluster of inline comments once.** Five comments each tagged "blocking 3" read as five blockers; anchor the finding on one comment and write "same fix" on the rest.

**A change description is a write target like the branch.** Editing a description is a blind full replacement, so a batch rewrite racing the change's writer silently restores an old body. Exclude every change with a live writer from batch rewrites; otherwise re-read immediately before each edit and abort if the updated-at stamp moved.

**For the hardest workstream, dispatch design-first; for under-specified tickets, run a scope-first round.** The writer reports a design or scope note for adjudication against the known failure history and opens no change until it is reviewed. One such round reversed three earlier conclusions before any code existed.

**Before handing off an orchestrator brief, trace every permission and every restriction to one of three sources: the human's actual words (quote them), a concrete technical reason, or a named incident.** Label your own recommendations as yours and drop the rest. Compaction summaries launder self-imposed guardrails into "standing constraints": one "take no other action" note on a single task grew, summary by summary, into a list of prohibitions the human had never stated and that blocked work they wanted.

## Decision discipline

**Get an explicit go, in the human's own words, before spawning writers, creating branches or changing any change's state for a program.** Urgency is not authorisation, and neither is an agreed plan. If a message is ambiguous, answer the question literally ("No, not yet") and ask "Launch now?". Set up the tracker before dispatch. An unrequested nine-writer fan-out had to be killed whole. A "Phase G #N" instruction is that go for the fix writers on PR #N.

**Before listing anything as an open decision, search the decision log and the tracker's resolved section.** A writer's "left for the human" comes from local evidence and is not proof the question is open. If it was decided, cite the decision and treat the mismatch as a fix. Re-asking a settled call wastes the human's attention and once held two changes for nothing.

**"Scope X" means write X up as a proposal.** Label it not-decided, give it no decision number, dispatch nothing, and let nothing downstream depend on it. Before logging a decision as the human's, quote the sentence in which they decided; if you cannot, it is a proposal.

**For a low-stakes reversible call, decide once, say it once, and do not revisit it without new information.** Reversing mid-flight costs more than either option; one trivial include-or-defer choice was flipped four times and whipsawed the writer. If you catch yourself reversing, accept the writer's current state and send nothing further.

**A hold pending capacity gets a re-measure trigger armed in the same turn, one that fires when the constraint clears.** Work watchers never fire on an idle machine, so a capacity hold has no natural trigger and silently becomes permanent: five finished changes once waited overnight behind a load figure that had been false for hours. Restate the measurement and its time whenever you repeat the hold; older than about an hour, it is no longer evidence.

**Serialise only what the dependency actually binds.** If two changes in a queue depend on the pin and three do not, the three do not wait. A gated change whose base moved owes a composition re-check, not a fresh gate round; gate in parallel, merge in series.

**Design work kept local is invisible to other people's agents and gets superseded.** Open a draft early; eight gate rounds on a local design were invalidated by a parallel change nobody on either side could see. (Opening the draft still needs the go above.)

## Scope discipline

**Before designing, ask what the simplest version that serves the request is, and do not touch production paths when a local change would do.** One "check CI before running tests locally" request grew into two changes, a production-path edit and sixty-four fix items before the human asked why.

**When reporting a plan's status, say three things separately: what is committed, what is planned at task level and reviewed, and what is committed but unplanned.** Say it before "ready to start". Coverage-map rows that point only at a one-line roadmap entry are "not yet planned".

**A "code complete by X" or timeline claim names the repos it covers and lists every other repo the release needs.** A precondition parked under the human's name becomes an assigned workstream or a question the moment it is found, not a line in a table.

**Every placeholder or deferred item gets a tracked owner task at the moment it is created.** Audit the plan for workstreams "riding with a sibling" that were never dispatched; two fell through that way and slipped integration by a day.

**When condensing a source document into a work register, diff for dropped clauses, and ticket anything deferred to "later".** The dropped clause and the unticketed backlog became the next urgent work.

**Do not present agent effort as a schedule.** Plan around the serial bottleneck (the merge queue, CI round trips) and bundle changes by code collision, not one change per finding. Changes that rewrite the same core file are sequential even when logically separable; only their design work can overlap.

**Fix a client-visible defect in the repo where its root cause lives.** A client-side workaround for a server contract gap becomes a second mechanism, which the server then rejects.

## Per-host autonomy settings (confirm with the human, record in LOCAL.md)

These were grants one human gave on one project. None is doctrine. Ask each once at setup and record the answer; absent an answer, use the conservative option listed first (item 7 excepted).

1. **Decisions during a run.** Surface every real fork to the human and wait — or take your own recommendation unless the call is critical with no clear best option, log it (call, option, why), and keep moving?
2. **Starting needed work.** Ask before starting anything not already dispatched — or start well-scoped, clearly needed work after a box-resource check and report that it started?
3. **Follow-ups on the program's own changes.** Ask before acting on review follow-ups, test hardening and fail-closed fixes — or do them inside a launched program and report "doing X"? Which items always remain asks (deploys, other people's changes, product decisions, external releases, anything loosening a security property)?
4. **Honouring a constraint the human just stated.** Ask before a reversible action that honours it (pull a change from the queue, stop a run, hold a push) — or do it at once and report?
5. **Landing authority.** Orchestrator lands nothing — or lands integration-branch changes after the gate? If so, under which checks, and does a pre-authorisation cover only the list named at the time?
6. **Replying to review bots on the forge.** Post triage replies only when approved each time — or standing-authorised to post them, with fixes still going through writer and gate?
7. **Stacked changes.** Default: SKILL.md loop step 3 (merge-as-you-go; stack only when a dependency genuinely cannot merge yet). Ask whether this human forbids stacking outright.
8. **Gating trivial changes on an integration branch.** Every change gets the full gate — or the human names classes that may skip it?
9. **Threat model default.** Assume adversarial inputs unless told otherwise — or are internal tools here used only by trusted colleagues, so reviews target correctness for honest use?
10. **Other people's changes.** Never touch them — or may you open your own change carrying their commits with credit, or one stacked on their branch? Pushing to, retargeting or commenting on their branch stays off unless they or the human say otherwise.
11. **Trackers and chat.** May the orchestrator create and edit tickets and post in team channels on its own, or only draft for the human?
12. **Where tests run.** Full suites in hosted CI with targeted runs locally — or full suites locally first because the box can take it?
