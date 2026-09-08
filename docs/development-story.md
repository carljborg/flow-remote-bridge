# From a failed paste to a working handoff

## The original symptom

A powerful Mac was serving as an always-on remote workstation. Its user connected from a local Mac and a Windows 11 handheld, with Wispr Flow handling most typing on both clients.

Dictation itself worked. Flow listened, produced text, and inserted it into local apps. Inside Parsec, the automatic insertion failed. Yet copying text locally and issuing a normal paste into the remote session worked. That separated a transcription problem from an input-delivery problem.

## Why not watch every clipboard change?

A clipboard watcher cannot reliably tell a dictation from a copied password, URL, file reference or ordinary text. Automatically pasting every change would also target whatever happened to be focused later. Matching clipboard text to a timer around a shortcut still leaves ambiguity.

We looked for a Flow-specific event. Local inspection of the installed application's behavior and metadata showed a SQLite history table with dictation IDs, target app identity, processing state and final/pasted text. No app patching, code injection or proprietary code redistribution was needed. Internal extension-related symbols were also present, but we did not find a stable supported user-facing completion hook suitable for this integration.

The selected approach reads newly created history records in place, in read-only mode. It does not copy live database/WAL files and does not read audio or screenshots. The tradeoff is dependence on an undocumented schema and local-history retention.

## Separate transport from insertion

Trying another synthetic keypress on the local machine could hit the same remote-input problem. Instead, the client sends the finished text through existing SSH connectivity. A small native Mac app then performs the paste inside the destination's own GUI session.

The first Windows experiment attempted to read the live Windows Flow database through WSL. SQLite reported I/O trouble with that setup. The working version uses Windows' native SQLite DLL for database access and keeps WSL only for the already-established SSH route.

The receiver owns clipboard restoration and target checks. A one-use arm token binds each attempt to the field observed before delivery, and an ID journal prevents automatically repeating an uncertain paste.

## What was actually tested

The original deployment passed:

- Private SSH transport from both client platforms.
- Unicode paste into a disposable Mac text document from each client.
- Repeated delivery of the same ID rejected without another paste.
- A focus/value change cancelling an attempt.
- Real spoken Flow dictation from both the Mac and Windows clients, confirmed by the user.

Public packaging adds generic configuration, scoped installers, source builds, synthetic tests and CI. Those changes are build/policy-tested; a clean-machine installation across every OS/app version is not claimed. The user's existing working private deployment is separate from this public package.

## What remains imperfect

The bridge is a practical integration, not a supported vendor protocol. App updates can change History fields. The Parsec log check lacks host-identity validation. Accessibility is not equally descriptive in every application. Clipboard races and late native insertion can still happen. We chose explicit cancellation and manual recovery over automatic retries that might paste twice or into the wrong field.

Future work should prioritize supported Flow completion hooks if they become available, stronger remote-peer validation, adapter-specific test coverage, and easier signed distribution—not a generic clipboard autopaster.
