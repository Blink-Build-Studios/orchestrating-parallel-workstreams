# agy (antigravity) quirks

Read this when an agent on this tool misbehaves, or before spawning it for the first time on a new box. Tool behaviour goes stale: every entry carries the date it was last observed; re-check against `--help` before relying on one.

Spawn flags, the front-loaded first-send prompt and the in-the-moment fix for the first-run trust dialog are in the runbook (§2, §3, §10). Working looks like a spinner plus "esc to cancel"; idle is an empty prompt.

## Costliest first

**A review cites quoted document text, paths, branches, SHAs, run ids, test counts or constant values that exist nowhere in the reviewed material.** agy invents supporting detail in its narrative sections while its executed checks and code-level findings are often the best of the three. Require pasted `grep -n -F` output for every citation in the brief and say unquotable findings are discarded; grep each quoted string yourself before acting; ignore its free-text "checked" prose as evidence. Do not drop it from the trio for this. _(observed 2026-11; unverified)_

**Seat sent "starting review", then sits `listening: blocked` or `launch_blocked` with no review file, on a worktree it has already been running in.** The folder-trust dialog is not only a first-run event: agy can re-show it mid-run and on every wake, and Claude Code's trust store does not cover it. Prevention is a human step (global config): add the worktree base directory to `trustedWorkspaces` in `~/.gemini/antigravity-cli/settings.json` once, editing the JSON array (re-check the path on a new build). For a seat already stuck in a worktree you just created from the repo under work, `hcom term inject <name> --enter` each time; for any other directory, leave the seat parked and ask the human. Look at any `blocked` seat's screen before nudging it by bus. _(observed 2026-09; unverified)_

**Screen shows "Model unavailable (attempt N/9)" then "There was a network issue connecting to the server", worse on large contexts; injected continuations fail the same way.** If the orchestrator's sessions run behind a local HTTPS proxy, agy inherits the proxy environment and long model streams are cut after a minute or so. Wrap the agy binary in a small script that unsets `HTTPS_PROXY`/`HTTP_PROXY`/`ALL_PROXY` (both cases) and re-check the wrapper after agy auto-updates; independently, have agy write its review file in sections as it goes and split very large scopes. If it keeps failing, kill it and run the one-shot form. _(observed 2026-10; unverified)_

**The gate's "third model" verdict reads like the first one.** The antigravity seat can silently come up as a claude session when antigravity is stale, turning a three-model gate into two. Check `hcom list -v <name>` for `Tool: antigravity` on the tag's instance before counting its verdict. _(observed 2026-11; unverified)_

## Other symptoms

**A box core is pinned for hours by a reviewer that already delivered.** An idle headless agy can spin near 100% CPU after its verdict. Kill each reviewer by exact name as soon as its review file is archived, not at approval time. _(observed 2026-08; unverified)_

**Seat asks "Do you want to proceed?" on every tool call, or reads as `launch_blocked`; it sat 18 minutes on a status command.** It was spawned without the autonomy flag. Do not answer its permission prompts for it; kill it and respawn with the runbook §2 flags. _(observed 2026-08; unverified)_

**agy cannot find the brief, or writes its review somewhere unexpected.** Its tool working directory is its own scratch directory, not `--dir`. Give absolute paths for the brief, every file to read and the review file to write. _(observed 2026-08; unverified)_

**A woken seat's input box holds garbled text or a stray "> N" after you inject a follow-up.** After a context compaction agy's TUI does not take an injected line cleanly. Kill it and spawn a fresh agy with the brief path in `--hcom-prompt`; a follow-up round gets its own tag and worktree like any other round. _(observed 2026-11; unverified)_

**One-shot `agy -p` run from the orchestrator's shell writes its review but its final send fails: "@<orch> is you; agents don't receive their own messages".** It inherited the orchestrator's `HCOM_INSTANCE_NAME`. Have the prompt send with an explicit sender (`hcom send @<orch> --from agy-<tag> --intent inform --file <path>`), and poll the review file once the process exits. _(observed 2026-10; unverified)_

**One-shot `agy -p "<prompt>" < /dev/null` produces "no output produced — a tool required the command permission".** Reported cause: the plain form refuses tools headless without `--dangerously-skip-permissions`. Not reproduced on agy 1.5.10, where the plain form ran a shell tool and returned output; add the flag only if you see this message. _(observed 2026-10; not reproduced on agy 1.5.10; likely stale)_

**Verdict line says `PASS` (or another word) instead of the required `READY`.** agy does not always keep to the verdict vocabulary. Spell out the allowed words in the brief and read the file rather than pattern-matching one token. _(observed 2026-11; unverified)_
