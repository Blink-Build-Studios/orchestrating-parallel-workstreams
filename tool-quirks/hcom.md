# hcom quirks

Read this when an agent on this tool misbehaves, or before spawning it for the first time on a new box. Tool behaviour goes stale: every entry carries the date it was last observed; re-check against `--help` before relying on one.

Notation: `<orch>` is the orchestrator's bus name, `<name>` an agent's. Spawn flags, the `--go` rule, PTY-teardown deaths and identity drift/reclaim are in the runbook (§2, §9); this file holds what the runbook lacks.

## Costliest first

**The roster says `active` (or `active: Bash`, `active (deliver:<orch>)`) for a long time, but no file, commit or report appears.** Roster status is not process truth: an agent parked behind a startup menu, a provider banner or an error stays "active" for hours. Look at the screen before anything else: `hcom term <name>`, and judge by the bottom lines, not scrollback; then `hcom list <name> -v` for `Unread:` and State Age. `active` + non-zero `Unread` + an unchanging State Age means frozen. _(observed 2026-11; unverified)_

**Every agent an orchestrator spawned dies within one second, roster shows `process_identity_gone`, and the orchestrator session ended too.** Agents spawned from the orchestrator's shell live in the orchestrator's systemd scope, so when that process exits, or the OOM killer hits any member (default scope policy stops the whole scope), all of them go together. Launch each agent in its own scope with a memory cap sized from measured peaks: `systemd-run --user --scope --unit=<prefix>-<name>-$(date +%s) -p MemoryMax=<N>G --quiet -- hcom 1 <tool> … --go`; confirm with `cut -d/ -f6- /proc/<pid>/cgroup`. `setsid -f` is not enough (same scope, and it once fired a delayed second launch that put two writers on one worktree). _(observed 2026-11; unverified)_

**Text you injected sits in the agent's input box; roster shows `listening: uncommitted text`, `tui:prompt-has-text` or `blocked`.** Three causes: an `@` in typed text triggers file autocomplete in the codex and agy TUIs; an Enter sent in the same call as the text can be swallowed; text over a few hundred characters lands as a paste block that eats the Enter. Clear with `hcom term inject <name> $'\x15'` (Ctrl+U) until the box is empty, inject one short line with no `@` that points at a file, then send `hcom term inject <name> --enter` as a separate call, and re-check `hcom list | grep <name>`; if text is still pending, send the bare Enter again. Bus messages (`hcom send @<name> --file`) are unaffected. _(observed 2026-11; unverified)_

**A reviewer that was still running vanished when you cleaned up a finished gate.** `hcom kill tag:<tag>` kills every seat carrying the tag, including a writer or a long-running extra reviewer that shares it (the tag-wide kill is the verified part); a seat launched with transcript saving off cannot be resumed and its run is lost. Kill by the exact names that delivered verdicts, give writers a different tag from their reviewers, and respawn a lost seat under a new tag. _(observed 2026-10; tag-wide kill verified hcom 0.7.31; resume claim unverified)_

## Spawning

**Spawn command exits 0 and prints a launch preview; no agent appears.** `hcom 1 <tool> …` without `--go` only previews. Add `--go`, then confirm the seat exists with `hcom list | grep <tag>`. Resume (`hcom r <name>`) is reported to behave the same, as is a tool whose `--help` does not list the flag (both unverified). _(observed 2026-11; `--go` preview verified hcom 0.7.31; resume unverified)_

**Parallel spawns fail with `No instances launched (0/1): database is locked`.** Concurrent launches on a busy bus race for the bus database. Relaunch only the failed ones, serially; take the exact lines from the spawn script's dry-run mode. _(observed 2026-11; unverified)_

**Launcher prints "Still launching after Ns".** That line means the spawn succeeded and is slow to bind, not that it failed. Do nothing; retry only on an explicit error line, because retrying here produced duplicate reviewers. _(observed 2026-11; unverified)_

**You recorded a verdict under the wrong model.** "All instances ready: <name>" pings arrive in boot order, not spawn order, and names are random. Read the tool from `hcom list -v <name>` (the `Tool:` line) and the brief's directory before filing a verdict under a model column or re-handing a brief to a seat that came up idle. _(observed 2026-09; unverified)_

**Your own bus name lost its tag prefix after a resume.** Resuming the orchestrator through the bus can re-register it under the bare name. Run `hcom list self` after any resume and fix every `@<orch>` in briefs before spawning. _(observed 2026-09; unverified)_

## Messages that go nowhere

**A tag-addressed broadcast (`hcom send @<tag>- …`) reaches none of your writers.** A tag send reaches only agents carrying that tag, which may be just your own in-process subagents. Read the `Sent to:` line on every send and list each `@name`, or spawn writers with a shared `--tag`. _(observed 2026-09; unverified)_

**Agents' sends to you never arrive for hours, yet `hcom list self` prints your name.** You are a forked or background job: you inherited the parent's name through the environment while the bus instance is still bound to the parent session, so wakes go to the parent. Check `hcom list -v <orch> | grep Session` against your own session id; if they differ, `cd` to the directory the identity was created in (reclaim refuses from any other) and run `hcom start --as <orch>`. Do not kill-and-resume: that resumes the parent. _(observed 2026-09; unverified)_

**You cannot tell whether your send was delivered.** `hcom transcript <agent>` does not reliably show inbound bus messages; a false "not delivered" read caused a duplicate send. Confirm from `hcom events --last N --type message` or the `Sent to:` line. _(observed 2026-09; unverified)_

**An agent promised a report, went `listening`, and nothing arrived, though your identity is intact.** Pings are occasionally dropped even with a healthy identity. Read the agent's last sent message with `hcom events --agent <name> --type message --last 1` and its verdict file before assuming it is still working. _(observed 2026-09; unverified)_

**A follow-up task sent to an agent that already finished is not acted on; roster shows `listening: mod unavailable`, `listening: blocked`, or stale `active` with unread messages.** A finished headless agent may not start a turn for a new bus message. Check within a minute of sending; wake it with `hcom term inject <name> '<one line with the brief path>' --enter --name <orch>`, or kill and respawn fresh. A bus message alone did not wake a parked codex. _(observed 2026-11; unverified)_

## Roster disagrees with reality

**A whole fleet flips to `stopped` / `process_exit by:system` in the same second while the processes are alive.** A bus command was run inside a PID-namespaced sandbox (a coding CLI's default sandboxed exec), where every other pid looks gone, and the bus cleaned them all up; the bus log shows a burst of `process_identity_gone … current=<gone>` under one instance. Busy agents re-register on their next hook; for idle ones, read `HCOM_*` from `/proc/<pid>/environ`, run `env -i HOME=… PATH=… <those vars> hcom start --as <name>`, then `hcom term inject <name> '<short note>' --enter`. Prevention: sandboxed agents run bus commands through host exec only; `ls /proc | grep -c '^[0-9]'` in single digits means you are in the sandbox. _(observed 2026-10; unverified)_

**An agent marked `stopped` still answers messages or edits files; two processes interleave one transcript.** The original process outlived the roster row and a resumed copy now shares the name; the roster shows one row. List the processes by environment (next entry) and tell them apart with `pstree -sp <pid>`. Killing one closes every PTY bound to that name, so warn the human and hand them the resume command first. _(observed 2026-10; unverified)_

**You need the process behind a bus name.** A launched agent's environment contains `HCOM_INSTANCE_NAME`. `grep -lzx 'HCOM_INSTANCE_NAME=<name>' /proc/[0-9]*/environ 2>/dev/null` lists every process that carries the name (the agent and its children); the agent is the one whose parent is not in the list. _(observed 2026-11; env var verified hcom 0.7.31; command unverified)_

**CPU-based liveness calls a blocked agent "productive", or a finished one "busy".** A claude seat parked at a dialog ticks about a second of CPU every few minutes, an idle codex tree gains a few CPU-seconds a minute, and an idle agy can spin a full core. Never use CPU alone: combine durable output (file mtimes, commits), the screen's working indicator, and known banner text. _(observed 2026-10; unverified)_

## Killing and resuming

**`hcom kill a b c` stopped partway and left agents running.** A multi-name kill aborts on the first name that no longer exists. Kill one name per command. _(observed 2026-08; unverified)_

**Cleaning up orphan processes killed a live writer, or your own shell (exit 144).** Every bus-spawned agent's command line embeds the bus system context, which names every tool, and a match against full command lines also matches the shell running it. Never kill by pattern. Identify an orphan by exact PID, parent lineage, cwd and start time, confirm its identity line with `tr '\0' '\n' </proc/<pid>/cmdline | grep -c 'Your name: <name>'` (prints a count, not the argv), then `kill <pid>` and verify with `ps -p <pid>`. Never print an agent's full argv (`ps -o args`): it contains the whole dispatch prompt. _(observed 2026-10; unverified)_

**Every later `hcom r <name>` exits code 2, "cannot be used multiple times".** Resume stores the original launch arguments, so repeating a flag on a resume duplicates it for good. Pass only arguments that change; if the seat is already poisoned, spawn a fresh one. _(observed 2026-10; unverified)_

**A resumed agent comes back with no window, or works in the wrong tree.** Resume reuses the previous launch mode (headless stays headless) and defaults `--dir` to the original worktree. Pass `--dir <current worktree> --go` explicitly and restate absolute paths in the first message. _(observed 2026-10; unverified)_
