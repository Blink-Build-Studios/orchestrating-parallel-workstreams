# Reviewer checklist

Read this before writing your verdict. It adds to the evidence bar in your review brief; it does not replace it. Almost every withdrawn "clear" this list was built from had one cause: a path the reviewer never traced, covered by a verdict that sounded as if it had been.

## 1. What your verdict may claim

1. **Scope the verdict to the paths you traced, and list them.** Write "first-write binding: clear", not "no blocking findings", give the call sites as `file:line`, and list the rest as untraced. A clear with no traced call sites is provisional; a narrow honest verdict is usable, a broad wrong one gets merged on.
2. **Walk the lifecycle, not just the happy path.** First write, later write, retry, delete, failure-then-retry, and retry after an unknown outcome are separate paths, and the bug is usually in the one the diff does not show.
3. **Trace the exact version your claim is about.** Behaviour carried over from a neighbouring version or flow is the commonest wrong premise. A fact attached to an existing record must be read at that record's pinned version, not the latest.
4. **Say what you executed and what you only read.** Several lanes once returned ready on new tests none of them ran, each trusting a run ID. If your brief forbids building but also demands execution, report the conflict instead of quietly skipping.
5. **Measure gaps and residuals against what the change itself claims.** A missing sync that breaks the stated crash-safety promise is not minor because "the filesystem probably covers it". A leftover case that contradicts the change's own spec text is a finding or the owner's policy call, never yours to accept.
6. **Check a deferral before accepting it.** When the author says a fix is blocked on a missing API or field, search the routes and schemas first; it often already exists and the gap is fixable in this change.
7. **Take a feature flag's runtime state from the deployment configuration.** A code comment or app default saying "off today" is not the state of any real environment, and a severity built on it is wrong.

## 2. Evidence you must attach

8. **Every figure you cite must exist where you say it does.** Copy run IDs, pass counts, old-to-new values, constants and line numbers from the source; reviews have returned ready citing runs and deltas that existed nowhere. A cost or amount is traced for this case, not borrowed from a neighbouring flow.
9. **Recompute any numeric finding in one line and show the arithmetic.** A rounding or off-by-one finding that is itself off by one moves a constant on a false premise, and every document and client pinned to it follows.
10. **Name only consequences you traced.** "This then fails with error E" rides unchecked on the finding's credibility. If you did not follow the path to the outcome, write "assert the outcome the runtime actually produces".
11. **Prove library, CLI and framework behaviour with a minimal repro at the pinned version when your brief allows execution;** if it does not, label the claim "from static read, unproven" and name the repro that would settle it. Recalled parser and flag semantics are wrong often enough to matter. Toggle one attribute at a time; a repro that changes two things has not isolated the cause.
12. **Read the helper's body, not its name, doc comment or the change description.** A gate described as "accepted by every participant" once counted an error response as an acceptance, which made it hollow.
13. **For test evidence, quote the command CI runs, the summary line for the exact head, and the observed values.** A default run skips opt-in and slow suites, and a pass count from a different runner is not equivalent: one runner reported green while a forked child process had failed.
14. **When a test is said to cover X, ask for three things.** The declared expected outcome, a harness-asserted checkpoint showing X's path was reached, and a mutation at X that turns the test red. "N passed" and a re-blessed snapshot both accept whatever the fixture happened to produce.

## 3. Defect classes that diff-readers miss

Tests and guards that pass without testing:

15. **A golden fixture that fails before reaching the path it claims to cover.** It dies on a missing permission or setup step and the early failure gets pinned as the expected output. The sibling is a fixture loader that falls back to a baseline on a parse error; loaders must fail closed.
16. **A check over a derived set that passes when the set is empty.** Zero tests selected, two empty sets compared equal, "ran 0, expected 0". Require non-empty plus a checked-in lower bound that may only rise.
17. **A test that passes at a scale factor of 1 cannot distinguish two units.** Any comparison between a limit and a value in a convertible unit needs a case at the live, non-identity configuration value, with both sides' units stated.
18. **A constraint that lives in a different function or layer from the one everyone traced.** Tests that inject past the ingress path never call the validator. When a change stamps or rewrites a field of a validated message, read the pinned validator's whole rule set, not just how the field is hashed or encoded.
19. **A snapshot re-bless that hides a behaviour change behind a forced one.** When an input change mechanically moves every snapshot, byte-identity cannot be demanded. Ask for a digest over the semantic fields pinned from the old snapshots, and an attribution for each field that moved.
20. **A guard that enumerates bad spellings.** A regex or deny-list loses a round per sibling bypass; at the second one, ask for the structural form (parse the syntax, or allow only what equals a reviewed template). For name-resolution checkers, probe shadowing, rebinding and local scope, not just import forms.
21. **A consumer checked against a test fixture instead of the real producer.** Read what production emits: a field the backend hardcodes, or an error tag only one branch attaches, makes correct-looking consumer logic never match.

Shapes, bounds and versions:

22. **Client and server validated separately.** Feed the client's real request bodies, empty arrays and omitted fields included, through the server's validator before clearing either side.
23. **Comparison or decoding against the wrong serialized form.** Check the enum's wire casing at the serializer, and the type of every argument to an encode or format call, since already-encoded input gets encoded twice. For any parser, read the producer's serializer first.
24. **A branch that handles one variant of a wider type.** `ok: false` often covers "unknown" as well as "failed", and an action that ends one kind of record may do something else for another. Read every value of the producer's outcome type and the handler for every mode.
25. **A boundary operator dismissed as harmless.** Run the exact-equality case and the smallest-unit case before saying `>=` versus `>` does not matter.
26. **A changed constant or symbol with dependants out of view.** Search for hardcoded copies of the old value, equality checks against it, and every caller of an item whose visibility or build condition changed. Include tests, pinned packages and other repositories.
27. **A value the target will refuse.** When a change raises a count, passes a new flag or adds an import, read the pinned runtime, vendor schema or invoked tool for a maximum, a preflight check or an allowlist. Exceeding a ceiling may refuse the whole set, not just the excess.

Ordering, concurrency and durability:

28. **Snapshot shared state, release the lock, await, then decide and persist.** Anything that changed during the await is lost for good. A reconcile-on-read must compare-and-set against the exact record it read, and an action awaiting user input must re-validate for cancel and expiry before an irreversible start.
29. **A moved durability point.** When a rewrite acknowledges earlier, compare step by step what the new ack covers against the old. Follow any value drained into memory across every later await to where it is persisted; a restart in between loses it and replay skips it.
30. **A moved fatal check.** List every step between its old and new position and every later step it now prevents. An "availability only" failure may abort before cleanup that follows a destructive step.
31. **One participant that can stall the rest.** A side task awaited ahead of the main work wedges the loop on one permanent failure. With a shared budget, check at the documented minimum whether a consumer that cannot make progress still drains it.
32. **A durable write, counter or cap ahead of authentication.** It turns an unauthenticated request into a lockout. An attempt cap that is global instead of per-caller is a denial of service.
33. **A supersede rule without field coverage.** "A newer confirmed record clears older pending ones" is safe only if the newer record covers the same fields; otherwise an unrelated success wipes a pending stop.
34. **A rollback or restart in the wrong order.** Find the component that probes or binds its peer only at startup and make sure it starts last, or it comes up degraded and nothing restarts it.
35. **A retry after an unknown outcome that applies twice.** For payments and other non-idempotent actions, trace what the client builds after a timeout and whether both attempts can land. Check too whether a cached balance already includes the deduction about to be subtracted.
36. **A signed or authorised action with an unbound field.** At every step run the same list: signer, environment or tenant instance, kind, target, amount. Each must be bound to what the user selected, never to an unauthenticated read the client trusted.
37. **Cursor pagination whose sort and cursor disagree.** The ordering comparator and the cursor predicate must be the same function; test a tie exactly at the page boundary, or rows are skipped permanently.
38. **Output checked for safety but not for function.** When rendering moves to a new source, enumerate the terminal shapes (failed midway, empty content, stopped) and confirm each still draws, reading the client and not just the payload. For generated code a user will copy and deploy, trace entrypoint, initialisation and deploy flags end to end.

## 4. What not to do

39. **Do not write "harmless", "acceptable", "every time" or "can't happen" on inspection alone.** Each of those words marked a place where tracing stopped one step short of the defect. Simulate the second and third iteration with the state the first one left; a "leak on every run" may be a one-off and a "cannot starve" may fail on round two.
40. **Do not put process or duplicated labels in the review.** Which reviewer or round raised a finding is never the author's business, in comments or in any description you draft. Label a cluster of related comments once on an anchor comment and mark the others "same fix", or one blocker reads as five.
