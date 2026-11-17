# Adjudication and evidence

Read this when you are about to rule on a reviewer finding, accept a writer's "fixed" or "green" claim, or quote a fact in a brief. It adds to SKILL.md "Hard-won lessons"; the rule "adjudicate against source, never majority-vote" is assumed.

## Reading the source

**Read the exact committed object and name the SHA you read.** Use `git show <sha>:<path>` or a `base..head` diff. Never read source from a live reviewer's or writer's working copy; the reviewer's own `REVIEW-*` verdict file, which is the verdict of record, is the one exception. Executing lanes mutate files in place, and the working copy can show a mutation or pre-fix code at the moment you look. If a working-tree read disagrees with the diff, the diff wins.

**Fetch before you analyse, and read from the remote base, not the local checkout.** Local checkouts run hundreds of commits behind. Stale state gives wrong anchors, hides whole directories, and poisons test inputs: a stale fixture once produced a "regression" that was only an old file.

**Trace the whole path from entry to effect before accepting a finding.** A reviewer cites the lines that support its story; the refutation is usually a few lines further down the same handler, in an early return or a gate. List every gate between entry and the claimed effect before a ruling, a ticket or a document rests on the finding. One "confirmed" severe finding produced three artifacts and an extra round before someone read the next thirty lines.

**Trace a finding's premise, not only its location, before turning it into a fix rule.** A rule written from an untraced premise ("this path leaves the record stuck") created the real defect it was meant to prevent.

**Treat a reviewer's prediction or framing as a lead, not as repo state.** A reviewer predicted what some values would become on a new base; the writer read the prediction as an existing assertion and proposed a production change to satisfy it. Check the literal at the actual tip.

**A fact quoted in a brief names the enclosing type or handler it was read from.** A grep hit is not a fact until its container is confirmed: two fields attributed to the wrong response type sent a writer to implement against data the wire never sends, and it took a round to notice.

**When code disagrees with a published generated document, suspect the document first and check whether it is still generated.** A review majority once trusted the document.

## Numbers, citations and claims

**Recompute every finding that is a number before it enters a round list.** Rounding direction, thresholds, off-by-one, "first fails at N": a one-line calculation settles each. A blocking item to move a critical constant was dispatched on a reviewer's arithmetic that was simply wrong.

**Search for every figure, hash or quotation a reviewer cites before repeating it.** Some models fabricate citations and numbers while their code findings are sound, so good findings do not vouch for the figures next to them. A cited value that appears nowhere in the reviewer's worktree is invented.

**Settle a contested behavioural finding by running a repro, not by reading harder.** "The code rejects X" from a static read is not "X does not work": dynamic paths behaved differently from the source read, and rejecting on the read would have broken working user code. Report the observed behaviour.

**When one of a writer's "fixed" claims proves false, re-verify every "fixed" claim on that head.** Three false claims on one head were caught only because the first made a reviewer distrust the rest. The writer cites the test that pins each claim and a reviewer runs it; never launch a confirm round on the writer's word alone.

**Verify writer-reported SHAs against the remote before using them.** Transcription errors happen, and a brief or a pin built on a wrong SHA fails later and somewhere else.

**Before naming the cause of a failing test in any brief, open the test and read what its oracle actually compares.** A cause stated by the orchestrator anchors the writer and every reviewer; four reviewers marked a wrong attribution "closed by construction" and the next CI run failed identically. If you have not read the oracle, write "likely; unverified" and ask reviewers to confirm independently.

**Do not relay another agent's summary of logs as fact.** A second-hand summary carries its author's working hypothesis. If the raw lines are already on their way, wait for them before telling a third party to change course; if you must warn first, say the cause is unconfirmed and what would confirm it.

**A zero-match filter is not evidence of absence until it has matched a known positive.** Terminal colour codes defeated every pattern in one log search and a "0 occurrences" report was wrong.

**Verify that a change is in a build by its behaviour at runtime, and confirm which build was actually running before blaming it.** Searching a binary for a small constant fails when the compiler inlines it, and an error attributed to the new build turned out to come from the old one still deployed.

## Did CI actually prove it

**"Observed green" means the pipeline reached terminal success on that exact head with the expected jobs present and passing.** An empty, errored or shorter-than-expected check listing is red: a job being re-run drops out of the listing for a moment and the remaining rows are all "pass". A cancelled or timed-out run, a per-job snapshot, and the writer's local run do not count.

**Read per-job conclusions before citing CI.** A pipeline can report success with nearly every job skipped (draft gating, path rules, a missing label). Know the count of real successes a full run produces and expect it. Which trigger starts the full set is a `LOCAL.md` "Repo CI quirks" value.

**Accept evidence for a test set only from the exact command CI runs, with observed values quoted.** A different runner reported a pass where the CI runner failed, because it did not propagate a child process's failure. The writer quotes the runner's summary line for the exact head; a bare run id is not evidence.

**Name each new non-default test in the confirm brief and require at least one gate lane to execute it and quote what it observed.** Four reviewers once said ready without running two new opt-in tests; the fixtures did not even parse, so the tests had been comparing a baseline. Fixture loaders must fail closed on a parse error.

**Never read a test result through a pipe that hides the exit code.** `runner | tail` returns the status of `tail`; check the pipeline status or redirect to a file and test the exit code. A red test was pushed this way.

## Tests that pass without testing

**When a writer claims a test covers X, ask for three things: the declared expected outcome, a harness-asserted checkpoint proving X's path was reached, and a mutation at X that turns the test red.** A golden that dies before the path it exists to exercise still "passes" and pins the failure as the expected output. Prefer a harness rule (every case declares outcome and checkpoint) over per-case fixes.

**A test that demonstrates "X never happens" needs a mandatory positive control and a non-empty-input assertion.** Otherwise it passes vacuously on an empty set.

**A check that compares or counts a derived set must fail when the set is empty.** Replacing hand-typed counts with derived inventories removes drift and also removes the only detector of collapse: a truncated inventory selected zero tests and the equality check passed on two empty sets. Keep checked-in lower-bound floors that may only be raised.

**For a "this test is false-green" claim, require the full mutation record: applied, confirmed present in the file, test run, red-versus-green observed, restored — each mutation in its own worktree.** Anything less is an opinion about the test. A mutation that only exercises the test's own guard proves nothing about the code under test.

**When a change turns pinned tests or goldens red, prove each failure against the base before re-blessing.** Brief the writer to stop and report on a real regression; a blind re-bless once would have hidden a broken client contract.

## Local stand-ins for CI

**A local stand-in for CI must execute the repository's own CI job definitions, not a hand-listed subset.** Hand lists drift: one skipped lint, doc tests and feature-gated lanes, and a merge went in that failed to compile under features the stand-in never built.

**A local full-gate pass does not substitute for hosted CI on the exact head when hosted CI runs suites the local gate does not.** A merge on "gate ready + local pass" left the integration tip red on suites only hosted CI ran.

**Do not report a mass local failure as a finding against the code until a control that varies only the harness reproduces it.** Same tree, same profile, with and without the wrapper or sandbox; and run the unmodified base before blaming the branch. Hundreds of failures have turned out to be the harness.
