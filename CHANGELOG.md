# Changelog

## 0.1.1 — 2026-09-08

- Add delivery age and UTF-8 byte count to client status logs, without transcript contents or IDs.
- Add long multilingual payload round-trip tests on Python/macOS and Windows.
- Document investigation of long-dictation failures: the observed rejection was `field-edited`, not duration or size. The target-specific cause remains under investigation; focus safeguards are unchanged.
- Clarify the project's experimental sharing intent and improve repository discoverability.

This is a diagnostic/documentation update, not a claim that the reported long-dictation issue is fixed. The original live deployment is unchanged while that cause is investigated.

## 0.1.0 — 2026-09-08

Initial source release: Flow-specific Parsec watchers for macOS and Windows, macOS Accessibility paste receiver, SSH transport, focus/duplicate safeguards, per-user installers and uninstallers, documentation, and build/policy tests.

The original private implementation passed live dictation from both platforms. Public-package configuration/build changes have separate automated coverage; the release does not claim universal app/OS compatibility.
