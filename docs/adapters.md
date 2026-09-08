# Beyond Parsec

The idea is broader than Parsec: **observe a completed local Flow dictation, verify the intended remote session, and insert text inside the remote desktop using its native input mechanism**.

The current implementation is narrower. Only the Parsec client adapters and macOS destination receiver are implemented. Changing a bundle identifier alone is not enough to claim support for another remote tool.

## Adding a remote-desktop client

Keep the receiver protocol. Add a client adapter that answers:

1. Is the intended remote-desktop window foreground? A process name alone may include a connection manager or unrelated local windows.
2. Is that window connected, and to **which host**? Prefer a supported connection API. If logs are needed, test start, disconnect, reconnect, stale log and multiple-window cases.
3. What `History.app` identifier does Flow record for dictations aimed at that client? Inspect metadata locally with the owner's consent; don't commit real history.
4. Is the SSH destination the same desktop and user being displayed?
5. Does normal Flow paste already sometimes succeed? Validate duplicate behavior and delayed clipboard synchronization.

The natural extraction points are `foreground`/`Foreground`, `parsec_connected`/`Connected`, and the expected Flow app identifier. This release deliberately hard-codes the tested identifiers so an arbitrary config change cannot silently remove connection validation.

Potential candidates include Apple Screen Sharing and VNC into a Mac. They need their own connection/host checks and live tests. See the related [remote-wispr project](https://github.com/robertjordanjr/remote-wispr) for a separate Screen Sharing implementation.

## Adding a destination OS

A Windows destination needs a native interactive-session receiver, focus/secure-field checks, clipboard management and Ctrl+V synthesis. A Linux receiver needs equivalent clipboard and focus/input mechanisms, with particular care for Wayland's permission model. Neither exists here today.

RDP, Citrix and other managed desktops often have deliberate data-transfer restrictions. A separate SSH text path must be approved in that environment. This project does not provide a workaround for an organization's disabled clipboard or SSH policy.

## Acceptance criteria

An adapter contribution should include synthetic unit fixtures and a manual test report covering Unicode, multiline text in a safe editor, duplicate completion, focus changes, wrong host, reconnect, locked destination, restart without history replay, and competing clipboard changes. Document OS/app versions and remaining limitations. Never attach real transcript databases, audio, tokens or personal connection logs.
