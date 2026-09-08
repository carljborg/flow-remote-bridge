# Setup, operation, and removal

## 1. Establish the remote desktop and SSH first

The receiver runs in the destination Mac's **logged-in graphical user session**, not as a system daemon. Unlock/login must already be handled by your normal remote-access setup. This project does not change FileVault, automatic login, sleep, power settings, Parsec accounts, or network ACLs.

Set up SSH key authentication through a network you trust. A local SSH alias might look like this:

```sshconfig
Host remote-mac
    HostName your-mac.example.ts.net
    User your_mac_username
    IdentityFile ~/.ssh/your_existing_key
    IdentitiesOnly yes
```

Use your own hostname and key. Verify the host fingerprint through an independent trusted channel before accepting it. Then check:

```sh
ssh remote-mac true
ssh -o BatchMode=yes -o StrictHostKeyChecking=yes remote-mac true
```

On Windows, run those commands **inside the WSL distribution and Linux account specified in configuration**. A Windows OpenSSH key is not automatically available to WSL. This version deliberately uses WSL for SSH because that was the tested working environment; it does not need nested virtualization or read Flow's database through WSL. WSL 1 was used in the original deployment.

The SSH user must be the same user running the receiver in the Mac GUI. An admin account logged into someone else's desktop will not reach that user's receiver socket.

## 2. Install the receiver on the remote Mac

Install Python 3 and Apple command-line developer tools (or Xcode) using your normal package-management process. Confirm `python3 --version` and `xcrun swiftc --version` work. Full Xcode users may need to select its developer directory. Do not run the installer with sudo.

From the repository in a terminal inside the Mac desktop:

```sh
python3 scripts/install-macos.py receiver --start
```

The installer builds and ad-hoc signs `~/Applications/Flow Remote Bridge.app`, pins the current Python interpreter in `~/.local/bin/flow-remote-submit`, and loads `org.flowremotebridge.receiver` as a user LaunchAgent. It restarts if it exits. No administrator installation is required.

Allow the app under System Settings → Privacy & Security → Accessibility. This permits it to inspect focus and synthesize Cmd+V. Add the app with the `+` button if needed. Restart the LaunchAgent after a permission change if health still reports false:

```sh
launchctl kickstart -k "gui/$(id -u)/org.flowremotebridge.receiver"
printf '%s\n' '{"op":"health","client":"setup"}' | ~/.local/bin/flow-remote-submit
```

Expected: `status: ok`, `accessibility: true`, `locked: false` (key order may differ).

No incoming port beyond your existing SSH access is opened. Client identifiers are labels for deduplication, **not authentication credentials**.

## 3. Install a client

### macOS

```sh
python3 scripts/install-macos.py client
```

Edit `~/.config/flow-remote-bridge/config.json`. Set `ssh_host` to your tested alias and give this client a unique `client_id`. The two optional path settings default to the usual local Flow database and Parsec log locations. Don't point the database at an iCloud/network copy; use Flow's live local database.

```sh
python3 ~/.local/share/flow-remote-bridge/watch.py --health
launchctl bootstrap "gui/$(id -u)" "$HOME/Library/LaunchAgents/org.flowremotebridge.client.plist"
```

The frontmost-app helper uses NSWorkspace; the client does not require a new Accessibility permission merely to identify the foreground app. Flow and Parsec retain their own permissions.

### Windows 11

Use **Windows PowerShell 5.1**, not PowerShell 7: compilation uses .NET Framework's `System.Web.Extensions`. WSL and the selected distro must already be installed and initialized.

```powershell
.\scripts\install-windows.ps1
notepad "$env:LOCALAPPDATA\FlowRemoteBridge\config.json"
```

Set all four keys:

| Key | Meaning |
|---|---|
| `client_id` | Unique simple label, such as `windows-client` |
| `ssh_host` | Verified SSH alias available inside WSL |
| `wsl_distribution` | Installed distro name, such as `Ubuntu` |
| `wsl_user` | Linux username in that distro |

Identifiers deliberately exclude spaces and shell metacharacters in this release. The native watcher reads `%APPDATA%\Wispr Flow\flow.sqlite` with Windows' `winsqlite3.dll`. It does **not** copy the live DB/WAL files or disable SQLite locking.

Test the configured WSL account and host, replacing the example user:

```powershell
wsl -d Ubuntu -u your_linux_username -- ssh -o BatchMode=yes -o StrictHostKeyChecking=yes remote-mac true
$dir = Join-Path $env:LOCALAPPDATA 'FlowRemoteBridge'
Start-Process "$dir\FlowRemoteBridge.exe" -ArgumentList '--health' -Wait -RedirectStandardOutput "$dir\health.json"
Get-Content "$dir\health.json"
Enable-ScheduledTask -TaskName 'Flow Remote Bridge'
Start-ScheduledTask -TaskName 'Flow Remote Bridge'
```

Run `--health` while the watcher task is stopped, because its single-instance mutex also applies to the health command. The task starts at logon and is checked every minute, ignores concurrent starts, has no execution time limit, and is allowed on battery. It runs only in the interactive user's session. If your Windows policy prevents registering a task, your administrator must handle that policy; do not bypass it.

## 4. Validate real dictation

1. Confirm normal remote interaction works and SSH health succeeds.
2. Connect Parsec to the configured Mac. Keep this client dedicated to that destination while the watcher runs.
3. Open a disposable text document on the remote Mac; avoid terminals for this test.
4. Dictate a short phrase with local Flow. Keep Parsec and the remote text field focused until it arrives.
5. Repeat with punctuation and Unicode. Verify each phrase appears once.
6. Minimize Parsec during an armed dictation; verify no remote paste while away, then return to the original unchanged field and verify one paste. Separately change the remote destination; verify delivery is rejected rather than following focus.
7. Restart the watcher. Confirm old dictations do not reappear.

The host may be physically headless if its existing remote desktop works. A working GUI login and Accessibility context are still required.

## Logs and files

| Machine | Location |
|---|---|
| Mac receiver | `~/.local/state/flow-remote-bridge/` — socket, lock, consumed ID journal |
| Mac services | `~/Library/Logs/FlowRemoteBridge/` — status/error logs |
| Mac client | `~/.local/share/flow-remote-bridge/`, `~/.config/flow-remote-bridge/` |
| Windows client | `%LOCALAPPDATA%\FlowRemoteBridge\` — executable, config, status log |

Watcher logs contain statuses, not dictation text. Windows rotates the log at roughly 128 KB. macOS LaunchAgent logs currently need normal user-managed rotation. The consumed journal retains IDs for roughly seven days, pruned during successful delivery attempts; it does not contain transcripts.

## Pause, update, uninstall

Stop macOS forwarding:

```sh
launchctl bootout "gui/$(id -u)/org.flowremotebridge.client"
```

Stop Windows forwarding (also disable the task so the one-minute trigger does not restart it):

```powershell
Disable-ScheduledTask -TaskName 'Flow Remote Bridge'
Stop-ScheduledTask -TaskName 'Flow Remote Bridge'
```

For updates, stop the client, pull the desired repository version, rerun the installer, and repeat health plus a real dictation test. Config files are preserved. Rebuilding the receiver changes its ad-hoc code signature and may require removing/re-adding its Accessibility entry. A package-manager update that removes the pinned Python path also requires reinstalling the Mac helper.

Uninstall:

```sh
bash scripts/uninstall-macos.sh client
# On the host:
bash scripts/uninstall-macos.sh receiver
```

```powershell
.\scripts\uninstall-windows.ps1
```

Remove the receiver's Accessibility entry manually. Uninstallers retain configuration, logs and the consumed-ID journal for review; delete the listed project directories if you no longer need them. They do not remove Flow, Parsec, SSH keys, WSL or Tailscale.

**Do not run this public package and an older/private bridge simultaneously.** Different service names and state paths do not prevent both from forwarding the same dictation.
