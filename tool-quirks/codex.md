# codex quirks

Read this when an agent on this tool misbehaves, or before spawning it for the first time on a new box. Tool behaviour goes stale: every entry carries the date it was last observed; re-check against `--help` before relying on one.

When a codex agent looks idle or stuck, read this file and run `hcom term <name>` before doing any process forensics. Almost every entry below is "a dialog or banner the roster cannot see". Working looks like `Working (Ns` at the bottom of the screen; idle is an empty prompt.

## Costliest first

**Fresh or resumed agent never starts its task; roster shows `listening (tui:prompt-has-text)` or `active (deliver:<orch>)` for hours with your task as `Unread: 1`.** Codex opened on an "Update available" menu (1 Update / 2 Skip / 3 Skip until next version) whose default is Update; a bare Enter runs the self-update and the bus loses the PTY. Select Skip explicitly with `hcom term inject <name> '2' --enter --name <orch>`, then re-send the task, because the queued one may not be picked up. Durable fix, a human decision since it is global config: `check_for_update_on_startup = false` in `~/.codex/config.toml`; option 3 dismisses it box-wide until the next release. _(observed 2026-10; codex 0.148–0.163; unverified)_

**Agent shows `active: Bash` with a harmless last command and an old State Age; work is uncommitted in its worktree.** Its turn ended on a banner and it is sitting at an empty prompt: `Selected model is at capacity`, `You've hit your usage limit`, `{"detail":"Bad Request"}`, or `access token could not be refreshed`. Grep the screen: `hcom term <name> | tail -8 | grep -iE 'at capacity|different model|usage limit|Bad Request|could not be refreshed'`, then apply that banner's entry below. Never re-dispatch from scratch: the worktree holds the uncommitted round. _(observed 2026-11; unverified)_

**Writer or reviewer goes silent on security-flavoured work; screen shows "This content can't be shown" or a "Set up security" chooser over an empty prompt, roster still `active`.** The provider's content filter refused the turn, triggered by the task's subject or by the orchestrator's own wording (narrating an attack, pointing the agent at an adversarial review report) rather than by anything the agent did. If the work is honestly defensive engineering on first-party code, say so plainly, once, in the next instruction and restate each finding as the behaviour required ("returns a typed error for a count above its maximum", "releases the guard before returning") instead of as an attack story; dismiss the dialog with Esc only when the screen is idle (Esc interrupts a working turn), then send the restated line. If the restated instruction is refused again, stop: back up the seat's uncommitted work (`git diff HEAD --binary` plus untracked files), park the item under decisions-needed, and take it to the human. Do not retry with reworded prompts or a fresh seat. If the task cannot be honestly described as defensive work on your own code, stop and take it to the human; a security-setup enrolment the provider asks for is the account owner's to complete, not an unattended agent's. _(observed 2026-10; unverified)_

**A long injected instruction shows as `[Pasted Content N chars]` and nothing happens.** Text over a few hundred characters lands as a paste block and the trailing Enter is consumed by the paste. Keep injects to one short line that points at a file; if you already pasted, send `hcom term inject <name> --enter` on its own, repeatedly, until the screen shows `Working` (it has taken one to three), and confirm by the session log's mtime because banners are sticky. _(observed 2026-10; unverified)_

## Spawning and resuming

**Several codex launches report ready, then all but one go `stopped` seconds later; log says "another Codex process is using its local data … database is locked".** Cold starts race on a per-user SQLite lock held briefly at startup. Launch codex agents one at a time, about ten seconds apart (claude and agy can go in parallel with a single codex), and verify with `hcom list | grep <tag>`, not the launcher's ready line. _(observed 2026-09; unverified)_

**A writer's rounds are noticeably sloppier than its siblings'.** A spawn can come up on a lower model tier or effort than the config pins, with the same command and account. Check the model/effort footer after every spawn (`hcom term <name> | tail -3`); if wrong, kill and respawn passing the model explicitly (`-m <model>` on the fresh spawn; do not repeat it on a later resume, see hcom.md). _(observed 2026-09; unverified)_

**Resumed agent sits at `listening: uncommitted text`; screen asks "Choose working directory to resume this session".** Option 1, the default, is the old session directory; a bare Enter picks it. Inject `2` then Enter to take the current `--dir`. Resume also needs `--go`, rejects `--headless`, and defaults `--dir` to the original worktree. _(observed 2026-09; unverified)_

**A reviewer told to do a "STATIC review" runs nothing, though the brief expected tests.** Codex reads "static" as "execute nothing" (the same phrase only stops agy from writing). Say exactly which commands it may run, or send the override right after spawn. _(observed 2026-11; unverified)_

**Agent cannot post to the tracker or use another orchestrator-side integration.** Spawned codex agents do not inherit the orchestrator's MCP servers. Have the agent write the note to a file and post it yourself. _(observed 2026-08; unverified)_

## Banners behind an "active" roster row

**"Selected model is at capacity. Please try a different model."** Provider capacity; the agent idles at its prompt. Wake it with `hcom term inject <name> '<short resume line naming the exact step>' --enter`; a bus request alone has failed to wake it. If it keeps failing, kill it and spawn a fresh seat in the same worktree with `-m <other model>`; do not pass `-m` to `hcom r` for a seat spawned with one (hcom.md: a repeated flag breaks every later resume). _(observed 2026-10; unverified)_

**"You've hit your usage limit … try again at <date>" on every codex agent at once.** The account quota is exhausted; codex quota is separate from Claude usage. Sweep all screens, tell the human at once (it may be a one-line reset on their side, not a multi-day wait), then send each agent "continue exactly where you left off; reply with what you were doing". _(observed 2026-09; codex 0.153; unverified)_

**Footer says "weekly limit: N% left" but agents are still working.** The footer can outlive a quota reset. Before escalating, read the last `rate_limits` record in recently modified session logs under `~/.codex/sessions/` (glob every date directory; long-lived seats write under their start date); only a real "hit your usage limit" line or a used-percent near 100 is an outage. _(observed 2026-10; unverified)_

**"Approaching rate limits — switch to <other model>?" dialog.** It parks the agent, and an Esc + text + Enter sequence can accept the downgrade by accident. Inject `2` then Enter to keep the model, and check the footer afterwards. _(observed 2026-09; unverified)_

**"Your access token could not be refreshed because you have since logged out or signed in to another account."** Someone switched the codex login, or a seat sat idle for hours; every running session dies at its next token refresh, staggered over twenty minutes or more, and idle ones look fine until messaged. Before a planned switch, pause the fleet and have every writer commit; afterwards sweep screens for the line, then `hcom kill <name>` and `hcom r <name> --go` (transcript kept, new auth read). Let a long foreground job finish first, since the restart kills its child process. _(observed 2026-09; unverified)_

**"unexpected status 404 … backend-api/codex/responses", or an agent reports an approval/backend 404.** Check a second agent's screen; if it shows the same, the provider endpoint is down. Do not kill, resume or respawn (a fresh session cannot help); log it, wait, and send a short nudge when the endpoint answers. _(observed 2026-09; unverified)_

**`{"detail":"Bad Request"}` then an idle prompt, sometimes under a security-setup chooser.** An API error ended the turn and nothing restarts it; one writer sat five hours this way. Esc the chooser if the screen is idle, then inject a line restating the task and brief path; kill any stray server the dead turn left running, by PID. _(observed 2026-11; unverified)_

**Agent hit a limit mid-task, stays `active: Bash` for a long time, then vanishes from the roster.** The turn died; the roster lagged. Check `hcom events --agent <name>` and the worktree's uncommitted edits before assuming it is running; `hcom r <name> --dir <worktree> --go` once the limit clears. _(observed 2026-09; unverified)_

## Liveness

**Seat is `active`, `Unread: 0`, CPU flat or barely ticking.** A freeze can start mid-turn with nothing queued, so `Unread` alone misses it. The tell that works: status `active` while the session log (`~/.codex/sessions/YYYY/MM/DD/rollout-*.jsonl`) has had no write for 15 minutes; `listening` seats are merely idle. Give every dispatched writer its own liveness watcher; CI watchers exit and leave it uncovered. _(observed 2026-10; unverified)_

## Sandboxed-write spawns only

**Writer refuses `git push` ("automatic approval review … authorization unknown"), parks at a question, and a bus message authorising it is rejected as untrusted.** Codex's approval reviewer accepts authorisation for an external write only from the human; bus messages and brief text do not count. Have the human type the authorisation in that session, or, with the human's explicit say-so recorded in the status log, push from the writer's worktree yourself as a transport-only step. Never type into an agent's terminal on the human's behalf to satisfy its approval reviewer. Seen with sandboxed-write spawns; not expected under the full bypass flag. _(observed 2026-09; likely stale)_

**An existing writer refuses to work in a second worktree ("writable roots authorize only <original>").** A sandboxed writer can only write inside the directory it was spawned with. Spawn a new writer with `--dir <new worktree>`; keep the original on its own branch. _(observed 2026-09; likely stale)_
