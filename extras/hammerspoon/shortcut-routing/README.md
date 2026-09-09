# Select which Mac handles a shortcut

This optional macOS-to-macOS adapter routes a small, explicit set of shortcuts over SSH. It is separate from dictation. It is intended for a working bridge where some system shortcuts are still caught by the local Mac.

Parsec [requires HID capture for immersive mode on macOS](https://support.parsec.app/hc/en-us/articles/32361385571860-Immersive-Mode-Setting). Turning HID off to support local Hammerspoon controls means that selecting keyboard immersive mode alone does not capture all system shortcuts. Turning HID back on can bypass those local event taps. Decide which behavior you want before changing either setting.

The example routes Command+W, Command+Q, Command+Shift+4 and Command+Space remotely. Copy, paste, refresh and new-tab are left to Parsec. A modifier-only Wispr activation chord is not intercepted. Brightness and volume can remain local through your existing configuration. Removing a route means normal local/Parsec handling, not a guarantee of a local-only action.

## Files and configuration

| File | Location and purpose |
| --- | --- |
| `shortcut_router.lua` | Local Mac: exact-modifier event filter with held-key/release suppression |
| `routes.example.lua` | Local Mac: chosen shortcut-to-action table |
| `host_actions.example.lua` | Remote Mac: allowlisted action names (key descriptions are informational) |
| `submit-shortcut.py` | Remote Mac: authenticated SSH command target, validates and queues requests |
| `native_actions.lua` | Remote Mac: native menu actions, Spotlight activation and CleanShot URL API |
| `shortcut_receiver.lua` | Remote Mac: Hammerspoon queue consumer with Accessibility permission |

These are adapter components, not an automatic installer. Back up both Hammerspoon configurations first. Do not replace existing init files or enable duplicate routing modules. The original private deployment integrates this policy into its existing media transport; this public adapter uses a separate directory.

## Remote Mac

1. Copy `shortcut_receiver.lua` and `native_actions.lua` to `~/.hammerspoon/` and `host_actions.example.lua` to `~/.hammerspoon/shortcut_actions.lua`.
2. Copy `submit-shortcut.py` to `~/.local/bin/submit-shortcut.py`. Use an absolute Python 3 executable in your SSH command, since non-interactive PATH may differ.
3. Create private queue storage:

```sh
mkdir -p ~/.local/state/flow-shortcut-routing/queue
chmod 700 ~/.local/state/flow-shortcut-routing ~/.local/state/flow-shortcut-routing/queue
```

4. Add to your existing init, then reload Hammerspoon:

```lua
shortcutReceiver = require('shortcut_receiver')
```

Grant Accessibility to Hammerspoon through macOS if needed. The receiver needs a logged-in desktop and a focused window for app-specific shortcuts. Screenshots and Spotlight can run without a focused window. It is not a pre-login service. Enable Hammerspoon at login if desired.

## Local Mac

Copy `shortcut_router.lua` and your edited routes table into `~/.hammerspoon/`. Load the table under a name such as `shortcut_routes.lua`. Integrate the callback into ONE existing event tap, after any Wispr synthetic-paste filter, before other early returns:

```lua
local routeShortcut = require('shortcut_router').new({
    routes = require('shortcut_routes'),
    active = function()
        local app = hs.application.frontmostApplication()
        return bridgeConnected and app and app:bundleID() == 'tv.parsec.www'
    end,
    send = function(action)
        -- Enqueue action plus hs.timer.secondsSinceEpoch() into your SSH adapter.
        -- The receiver accepts only its configured action tokens.
        enqueueShortcut(action, hs.timer.secondsSinceEpoch())
    end,
})
-- Inside your keyDown/keyUp event callback:
-- if routeShortcut(event) then return true end
```

`bridgeConnected` and `enqueueShortcut` are integration points you must implement using your connection monitor and SSH sender. They are not globals supplied by this package. You can use the existing optional paste guard's `.status().connected` as the log-based signal, with the same dedicated-host limitations. Never treat foreground Parsec alone as proof of a connected session.

Your asynchronous SSH adapter should use `hs.task` with separate argument strings and run this command on your verified host:

```text
/absolute/path/to/python3 /Users/YOUR_USER/.local/bin/submit-shortcut.py CLOSE_WINDOW 
```

Do not use arbitrary user text as a command or shell-interpolate paths. Use key authentication, verified known_hosts, BatchMode, a short connection timeout, a bounded serial queue and no retries. An SSH ControlMaster can reduce latency. Use a local monotonic clock to drop queued requests older than two seconds before dispatch. The submitter stamps acceptance using the host clock, and the receiver expires queued requests using that same host clock. No client/host wall-clock comparison is made. This does not bound time already spent in SSH transit; use a short connection timeout and never retry uncertain actions. Surface failures locally, without sending the shortcut to a different destination.

The host rejects unknown tokens, unavailable permission/heartbeat or missing target windows for app-specific actions. Accepted requests expire two seconds after host submission. The timestamp argument from older senders is ignored. For app-specific actions, it captures the frontmost application/window at submission and checks again at delivery. Screenshot and Spotlight are system actions. This reduces focus races but cannot guarantee the same target as at the original physical keypress. Do not use this mechanism for unattended destructive shortcuts. It records only action IDs, times and application/window numeric IDs, not typing or transcript contents. No network listener is added; SSH account permissions remain your security boundary.

## Changing a route

To add a shortcut, add its local route and an explicit remote action token to both the host table and Python allowlist. Implement the corresponding native operation in `native_actions.lua`. The example key/modifier fields in the host table describe intent; they do not synthesize a keystroke. Do not reintroduce generic key injection as a fallback when a menu item is unavailable. Reload both ends after changes. Keep working copy/paste routes untouched.

To force a shortcut locally, add a separate gated local handler that consumes its original down/up and posts a tagged local event or calls the appropriate local API. Exclude your own synthetic-event tag to prevent a loop. Merely removing a remote route lets Parsec decide; it does not force locality. Brightness and system media keys use different event types, so they are not examples of ordinary Command shortcuts.

## Validation and rollback for humans and agents

1. Record which machine has the keyboard, which runs the target app, HID settings, and intended local exceptions.
2. Back up modules and preserve existing Accessibility grants. Never reset all privacy permissions as part of installation.
3. Run `lua5.4 tests/test_shortcut_router.lua` and `lua5.4 tests/test_shortcut_receiver.lua` from the repository root. Tests cover exact modifiers, repeat suppression, key release after focus changes, inactive mode and untouched C/V/R/T.
4. Verify both services are loaded and reject expired/unknown requests. Test with a disposable window first. Do not test quit against someone's working terminal or editor.
5. Physically test each shortcut once, verify only one destination acts, then test copy/paste, Wispr, volume and brightness. A mocked test is not proof of native keyboard behavior.
6. Test leaving Parsec and releasing a held key. The callback must still see key-up after focus changes, so do not put a foreground early-return before it.
7. To roll back, remove the callback from the existing tap and reload, then stop/remove the optional receiver. Do not kill Parsec or reboot either Mac as an installation step.

The original user confirmed close/quit routing but subsequent testing found interference with normal Command shortcuts in both synthetic-key implementations. Those versions are superseded. The current receiver performs native actions instead:

- Close/Quit: discover the unique enabled Command+W/Q menu item and invoke it through Accessibility. Preserve unsaved-document prompts; never force-kill the application. Missing or ambiguous menus cause a reported failure.
- Area screenshot: open `cleanshot://capture-area` on the host using [CleanShot's documented API](https://cleanshot.com/docs-api). CleanShot must be installed, registered and authorized for screen capture.
- Spotlight: activate Spotlight directly, or hide it when it is already frontmost. This does not promise exact keyboard-toggle semantics in every macOS release.

No ordinary keyboard or modifier events are injected by this action module. Media controls remain separate. The public regression tests verify dispatch, matching/focus rules and absence of keyboard synthesis; physical regression validation remains required. Windows clients need a Windows-native adapter. Other remote desktop products need their own foreground/connection detection and capture testing.
