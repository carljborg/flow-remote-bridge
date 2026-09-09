# Changelog

## Unreleased

- Add an opt-in macOS Hammerspoon guard for Wispr-generated V events leaking into focused Parsec before bridged dictation. No core bridge changes or automatic installation.
- Document observed event-source evidence, permission requirements, integration limits, disable/uninstall steps, and add mocked input-policy tests.

## v0.1.3 — Pause dictation while away from Parsec

- macOS and Windows keep already-armed dictations pending when Parsec loses foreground focus; return within 25 minutes of arming to attempt delivery to the original validated Mac field.
- Completed text remains pending while away. Final foreground-check failure no longer discards it. No background paste, destination rearming, expiry renewal, or retry of uncertain delivery.
- Existing receiver field/selection safeguards remain unchanged. Client restart discards pending history as before.
- Added pause/return/expiry regression coverage on both platforms.


## 0.1.2 — 2026-09-08

- Fix Apple Terminal dictation being rejected when background output changes its Accessibility scrollback value. Only its read-only terminal text area uses this policy; app/window/element identity checks remain and selected text blocks delivery.
- Keep strict draft and selection checks for editors, browsers and Terminal's other fields. Document terminal-specific limitations instead of promising universal app support.
- Add 12 pure field-policy regression cases to macOS CI and a metadata-only `inspect` operation.
- Align the installer app version with the source release.

## 0.1.1 — 2026-09-08

- Add delivery age and UTF-8 byte count to client status logs, without transcript contents or IDs.
- Add long multilingual payload round-trip tests on Python/macOS and Windows.
- Document investigation of long-dictation failures: the observed rejection was `field-edited`, not duration or size. The target-specific cause remains under investigation; focus safeguards are unchanged.
- Clarify the project's experimental sharing intent and improve repository discoverability.

This is a diagnostic/documentation update, not a claim that the reported long-dictation issue is fixed. The original live deployment is unchanged while that cause is investigated.

## 0.1.0 — 2026-09-08

Initial source release: Flow-specific Parsec watchers for macOS and Windows, macOS Accessibility paste receiver, SSH transport, focus/duplicate safeguards, per-user installers and uninstallers, documentation, and build/policy tests.

The original private implementation passed live dictation from both platforms. Public-package configuration/build changes have separate automated coverage; the release does not claim universal app/OS compatibility.
