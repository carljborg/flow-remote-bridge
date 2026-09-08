# Contributing

Small, reproducible improvements are welcome. For new remote-desktop adapters, read [docs/adapters.md](docs/adapters.md) first. Preserve target/focus checks and at-most-once attempt behavior.

Run Python tests, compile Swift on macOS, and run `tests/windows.ps1` in Windows PowerShell 5.1. CI checks those three paths. Update documentation when config, install paths or protocol behavior changes.

Manual integration checklist:

- Fresh install and health check; explicit receiver Accessibility approval.
- New dictation delivered once into a disposable text editor from each supported client.
- Unicode and multiline text preserved.
- Focus change and locked destination cancel safely.
- Duplicate ID rejected; watcher restart does not replay history.
- Disconnect/reconnect and service restart behave as documented.
- New clipboard copy is not overwritten by delayed restoration.
- Uninstall stops all project processes without changing Flow or Parsec.

Synthetic fixtures only: do not commit real Flow databases, logs with personal data, SSH keys, IP addresses, peer IDs, accounts, transcripts or binaries. Keep code and documentation independent of the maintainer's private deployment.

Submitting a contribution licenses it under the repository's MIT license. This project is unaffiliated with Wispr or Parsec; don't imply vendor support.
