# Optional macOS Parsec stray-V guard

Use this only if a working Flow Remote Bridge session receives a stray `v` before the completed dictation. This is a client-side Hammerspoon add-on, not part of the default installation. It is not needed on Windows.

## Why it exists

In the original deployment, this symptom appeared after Parsec's macOS HID keyboard capture was disabled to support separate media-key mappings. Event-source diagnostics identified Command+V events from Wispr's accessibility helper arriving before the bridge delivered the completed text. The remote application received a bare `v` from that separate input path.

The guard consumes only V key-down/up events originating from recognized Wispr processes, while Parsec is connected and foreground and `bridgeEnabled()` returns true. It does not strip a letter from your transcript or undo text. Physical V typing, manual Cmd+V, other applications, and the bridge's independent paste on the remote Mac are outside its filter. It does not intercept Command modifier events.

The deployed version was verified with repeated real dictations. This standalone package has mocked policy tests; each keyboard, Parsec version, and permission setup still needs a live test. If an event has an unknown source, the guard leaves it alone.

## Install on the local Mac running Wispr and Parsec

1. Install [Hammerspoon](https://www.hammerspoon.org/) if needed. Grant it Accessibility through System Settings. This permission allows observing and modifying keyboard events; this module handles only the described V events and does not log typed text.
2. Copy `flow_paste_guard.lua` into `~/.hammerspoon/`. Preserve your existing `init.lua`.
3. Append this configuration to `~/.hammerspoon/init.lua`:

```lua
-- Set false whenever you pause or stop Flow Remote Bridge.
flowBridgeEnabled = true
flowPasteGuard = require('flow_paste_guard').start({
    bridgeEnabled = function() return flowBridgeEnabled end,
})
```

4. Reload Hammerspoon's configuration. Enable its Launch at Login preference if you want it after login.
5. Connect Parsec to the same Mac configured in your bridge. Wait a second, focus a harmless text document remotely, and test dictation, normal V typing, and manual Cmd+V.

Do not disable Parsec HID mode just to install this add-on. The guard does not change Parsec settings, restart applications, install login jobs, grant permissions, or replace your existing Hammerspoon configuration. Raw HID capture can bypass event-tap suppression in some setups; this is not a universal keyboard-remapping solution.

## Limitations and recovery

- Keep the bridge running. Otherwise this guard can suppress Wispr's local paste without the bridge delivering replacement text. `bridgeEnabled()` is an explicit integration switch, not an automatic health check.
- Flow-history replay or other Wispr features that synthesize V while Parsec is foreground can also be suppressed. Disable the guard before using such a workflow if the bridge does not support it.
- The connection check reads the tail of Parsec's local log. Unknown state leaves input untouched. It does not identify the remote peer; use the same dedicated-host precautions as the main bridge.
- Process IDs are refreshed through native application lookup once per second. Wispr bundle IDs and Parsec log formats can change. No fixed PID, personal host, or SSH credential is included.
- Repeated key-source ambiguity, Secure Input, missing Accessibility permission, or different capture modes may prevent the filter working. Do not broaden it to suppress every V or every paste shortcut.
- No clipboard/history reading, transcription logging, network listener, or SSH transport is added. `flowPasteGuard.status()` exposes only connection state, event-tap state, and a suppression count.

To disable immediately, set `flowBridgeEnabled = false` or run `flowPasteGuard.stop()` in the Hammerspoon console. To uninstall, remove the configuration block, reload Hammerspoon, and remove the module. Your core bridge continues to work independently.

Media keys, volume routing and display brightness are separate personal customizations and are not included here.

## Tests

From the repository root, with Lua 5.4:

```sh
lua tests/test_flow_paste_guard.lua
```

References: [Hammerspoon event-source metadata](https://www.hammerspoon.org/docs/hs.eventtap.event.html), [native application lookup](https://www.hammerspoon.org/docs/hs.application.html), [Parsec HID keyboard capture](https://support.parsec.app/hc/en-us/articles/32381443626516-All-Advanced-Configuration-Options).
