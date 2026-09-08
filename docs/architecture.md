# Architecture and protocol

## Components

- `clients/macos/watch.py`: native Python SQLite polling, NSWorkspace foreground helper, native SSH.
- `clients/windows/FlowRemoteBridge.cs`: native Windows SQLite and foreground APIs, WSL OpenSSH transport. Background .NET Framework executable, with a named mutex preventing duplicate instances.
- `receiver/flow-remote-submit`: short Python stdin-to-Unix-socket relay, invoked through SSH.
- `receiver/Receiver.swift`: per-user macOS GUI agent. Focus inspection and paste actions are serialized on the main thread.

The remote desktop carries display/input. SSH carries dictation text separately. Neither endpoint depends on the remote desktop's clipboard synchronization working correctly for delivery.

## Finding the right text

Both watchers baseline `max(rowid)` in Flow's local `History` table when they start. They then poll roughly every 300 ms for newer rows and for updates to pending rows. Reads use SQLite read-only mode and normal locking. No Flow data is updated.

Only these columns are read: `rowid`, `transcriptEntityId`, `status`, `app`, `pastedText`, `formattedText`. SQL returns a text body only for the known Parsec app identifier (`tv.parsec.www` on macOS, `parsecd` on Windows). The preferred body is nonempty `pastedText`, otherwise `formattedText`, preserving spacing and Unicode.

A new row can first appear with no app/status. The watcher arms only while a connected Parsec client is foreground; it discards the pending entry if the app later resolves to something else. A `formatted` body must remain unchanged for at least 700 ms before submission. This is a debounce heuristic, not an official Flow completion contract. A future version that formats in delayed chunks could need a different strategy.

A maximum of 64 pending dictations bounds work. Pending entries expire after 25 minutes. A database/transport processing exception clears pending work; delivery is deliberately not retried. Historical retry inside Flow updates an old row and is not automatically forwarded by this watcher.

## Connection and focus checks

An already-armed row remains pending while Parsec is not foreground/connected. It is reconsidered on return, without creating a new receiver token or extending the original 25-minute client expiry. This also covers completion while away. A final foreground check precedes consuming the pending row and attempting delivery; an uncertain attempt is never retried. App-mismatched rows still cancel, and fresh dictations first observed outside Parsec are not armed. Watcher restart excludes old history rather than restoring pending text.

The Parsec adapter reads the tail of the client's log. The most recent connection-status or startup event must end with `Client Status received: 0`. It also checks the native foreground app/process.

**This does not identify which remote host is connected.** The SSH destination is fixed in configuration. Current users must dedicate that Parsec client session to the same host. A production multi-host adapter should validate the remote peer identity as well as connection state.

When arming, the Mac receiver retains the foreground process ID, focused Accessibility element and window, and available text value/selection. Before pasting it checks these again. Apple Terminal’s read-only AXTextArea is a special case: its value is display/scrollback and can change as output streams, so value and caret-offset changes are allowed while app/window/element identity remains required. A text selection at arming or delivery blocks this terminal path. Other fields retain strict value and selection comparisons. Locked screens, recognized secure fields and disabled fields are rejected. Missing Accessibility data weakens what can be checked: an app that exposes a single large view may not distinguish all internal text fields. Focus changes between the final check and OS event delivery remain possible.

## Wire format

One UTF-8 JSON object per SSH invocation, terminated by a newline. The receiver accepts at most 512 KiB of JSON and 64 KiB of UTF-8 text. The larger envelope permits JSON escaping. No text is placed in a shell argument.

Health:

```json
{"op":"health","client":"laptop"}
```

Typical response:

```json
{"status":"ok","accessibility":true,"locked":false}
```

Arm (ID must be a UUID; client is 1–64 letters, digits, `_` or `-`):

```json
{"op":"arm","client":"laptop","id":"11111111-1111-4111-8111-111111111111"}
```

Response contains `status: armed` and a random `token`. Paste must supply the same client, ID and token plus `text`. A token is consumed on the paste attempt, including cancellation. Arms expire after 30 minutes.

**Do not send arm/paste probes while someone is working in the destination desktop.** Use health for unattended diagnostics and a disposable text document for input tests.

## Delivery semantics

Before emitting Cmd+V, the receiver records the client/ID pair in a persistent journal. Repeating that ID returns `already-consumed`. For nonterminal fields, if the focused text/selection exposes the exact dictated suffix, it returns `already-inserted` instead of pasting again. That heuristic can also suppress an intentional repeated phrase; it is not a universal duplicate detector.

The clipboard is snapshotted in memory, temporarily replaced with plain text, and restored after 1.5 seconds **only if its change count has not changed**. This avoids overwriting a user's newer copy. No Enter event is emitted, but pasted newlines may still be interpreted by the destination application.

`paste-sent` means OS events were emitted, not that an application accepted the text. Crashes or network interruptions can leave delivery unknown. Automatic retry would risk duplicate text or a paste into the wrong place, so the clients remove pending work before sending. Recover deliberately from Flow history if needed.

## Persistence and authentication

A mode-0700 state directory contains the mode-0600 Unix socket and ID journal. The receiver uses an advisory lock to prevent multiple instances. SSH authenticates the OS user; the `client` label is not an authorization boundary. Any process with access as that same user can speak the protocol. The transport does not create a separate public listener or share your SSH keys with this repository.

The receiver requires the macOS user's explicit Accessibility permission. The installers neither edit the TCC database nor automate permission approval.
