# Security and privacy

This program moves dictated text between computers and grants a destination helper Accessibility control. Review the source and use it only between machines/accounts you trust and are authorized to connect.

## Trust boundaries

- SSH authenticates the destination OS user, with strict host-key checking. The project does not provision keys or relax SSH settings.
- The receiver socket is local and user-restricted. Any process acting as that same OS user can access it. Client IDs and tokens are delivery bookkeeping, not an alternative to OS authentication.
- The Mac receiver can inspect accessible UI focus/value/selection and synthesize Cmd+V. Permission is explicitly granted in System Settings. It is not sandboxed or notarized in this source-build release.
- Client connection checks are best-effort. **The current Parsec adapter does not verify remote peer identity.** Do not use it while connected to a different host from the configured SSH destination.
- Endpoint compromise, concurrent users, misleading Accessibility implementations, and focus changes between validation and event delivery are outside the guarantees of these checks.

## Data handling

The watchers read new Flow history metadata and qualifying text. They do not read audio/screenshot columns or change the database. Text exists transiently in process memory, encrypted SSH traffic and the destination clipboard. Focus snapshots can contain existing field text in memory. The bridge's persistent journal contains client/UUID/time values; logs contain statuses, not transcript bodies.

Flow's own history retention remains unchanged. Clipboard managers, remote clipboard synchronization, OS crash reports and other software may independently capture data. “No transcript logging by this project” is not a claim that the text never persists anywhere.

Clipboard restoration, secure-field detection and duplicate suppression are best-effort. **The helper does not press Enter, but multiline paste may execute commands in a shell.** Dictate into a text editor first and review commands before running them.

Do not use this as a way around managed-desktop clipboard or data-exfiltration controls. Obtain the relevant administrator's approval for any separate SSH transfer path.

## Reporting vulnerabilities

Use GitHub's private vulnerability reporting for this repository if enabled (Security → Advisories → Report a vulnerability). If that option is unavailable, open a minimal issue requesting a private reporting channel without including exploit details or sensitive material. There is no guaranteed response SLA.
