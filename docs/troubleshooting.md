# Troubleshooting

Start with a disposable text document. Don't debug by pasting commands into a terminal.

| Symptom/status | Check |
|---|---|
| `needs-accessibility` | Grant the receiver app Accessibility on the destination Mac; restart its LaunchAgent. Rebuilds can invalidate an ad-hoc permission entry. |
| `screen-locked` | Unlock the destination using your established remote-access process. |
| `transport-failed` | Verify the exact SSH alias/account, strict host-key check, key availability, network reachability and installed `.local/bin/flow-remote-submit`. |
| Windows health prints nothing | Stop/disable the watcher task first; its mutex prevents a second instance, including health mode. Check redirected stderr if config is invalid. |
| Waiting for database | Run Flow locally and ensure local history is available. Enterprise/“Never store” settings may make this approach unsuitable. |
| `Paused: OperationalError` / database query failure | Flow may have changed schema or reset its DB. Stop the watcher, inspect schema metadata locally, update if needed, restart. Never post the database publicly. |
| No new log activity | Verify Parsec is foreground and connected, and Flow's target app identifier still matches. Old history and retries of old records are intentionally ignored. |
| `no-focused-element` | The destination app doesn't expose a focused Accessibility element. Try TextEdit to isolate app support. |
| `focus-changed`, `field-edited`, `selection-changed` | The target changed during dictation, or the app exposes a changing composite element. Keep focus stable; don't weaken guards globally. |
| `secure-field` / `disabled-field` | The receiver declines recognized password or disabled controls. Use your usual manual input method. |
| `already-consumed` | The same ID was already attempted. The helper will not automatically replay it. |
| `already-inserted` | The exact dictated suffix was visible at the caret. The helper suppressed a possible duplicate; intentional repeated text may need manual handling. |
| `paste-sent`, but no text | OS events were emitted; this is not an insertion acknowledgment. Test another app and check focus, permissions and application-specific paste behavior. |
| Paste works twice | Ensure an older bridge is not also running. Flow may now be successfully pasting itself, while a target app doesn't expose enough text for duplicate suppression. Stop this bridge if native insertion works reliably. |
| Starts working only after login | Expected: receiver and watchers belong to interactive user sessions, not pre-login desktops. |
| Old clipboard isn't restored | Another app changed it during the 1.5-second window; preserving that newer copy takes priority. |

## Keyboard shortcuts are a separate issue

This bridge inserts on the Mac host; it does not fix ordinary Parsec keyboard mappings. On a Windows client, Parsec's Ctrl/Command swap can make Ctrl+U arrive as Cmd+U. Keyboard immersive mode affects special-key forwarding. Consult [Parsec's advanced settings](https://support.parsec.app/hc/en-us/articles/32381443626516-All-Advanced-Configuration-Options) and choose mappings that match your workflow. These installers do not change Parsec settings or your Flow shortcut.

## Reporting a problem

Include OS versions, Flow/Parsec versions, whether a safe manual paste works, health status, and redacted status-only watcher logs. State whether this is a clean public-package installation or a modified adapter. Never post dictation text, real Flow databases, screenshots containing private work, SSH material, authentication tokens or full app logs without reviewing them.

## A long dictation fails but a short one works

Check the status log before assuming a length limit. The watcher allows up to 25 minutes of pending dictation and the receiver accepts up to 64 KiB of UTF-8 text. `field-edited` means the destination's Accessibility value changed between arming and delivery; `selection-changed` means its selection changed. Neither indicates a transcript-size error.

The original failure occurred in Apple Terminal: a roughly six-minute dictation of about 3,200 characters was rejected as `field-edited`. Terminal exposes its display/scrollback as `AXValue`; ordinary background output can change it without the user editing an input draft. Version 0.1.2 treats Apple's read-only `AXTextArea` terminal surface specially: it permits output/caret changes while retaining app, window and element identity checks, and refuses a nonempty text selection. Terminal search fields and other applications retain strict draft/selection checks.

This policy cannot distinguish a shell input edit from output, or a command/program change within the same terminal pane. Keep the intended terminal input active while dictating. No Enter is sent by the bridge, but multiline paste behavior depends on the receiving program. Other terminals need independently validated adapters; the Apple Terminal exception does not apply to every terminal-like app.

The receiver's `inspect` operation reports only the current app bundle, Accessibility role, terminal-policy eligibility and selection length—never field contents. This helps determine whether a different destination needs an adapter. `terminal-selection-active` means text was selected when arming or delivering; `terminal-selection-unavailable` means the receiver cannot safely verify that condition.

Do not solve other failures by automatically rearming or removing all focus checks: that can paste into a different task or repeat text. Failed delivery requires deliberate manual paste or a new dictation; uncertain deliveries are never retried automatically.
