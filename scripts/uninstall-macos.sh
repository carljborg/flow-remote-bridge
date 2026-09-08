#!/bin/bash
set -eu
role="${1:-}"
case "$role" in receiver|client) ;; *) echo 'Usage: uninstall-macos.sh receiver|client'; exit 2;; esac
label="org.flowremotebridge.$role"
launchctl bootout "gui/$(id -u)/$label" 2>/dev/null || true
rm -f "$HOME/Library/LaunchAgents/$label.plist"
if [ "$role" = receiver ]; then
    rm -rf "$HOME/Applications/Flow Remote Bridge.app"
    rm -f "$HOME/.local/bin/flow-remote-submit"
    echo 'Remove Flow Remote Bridge from Accessibility in System Settings.'
else
    rm -rf "$HOME/.local/share/flow-remote-bridge"
fi
echo 'Configuration, status logs and ID journal retained for review; see docs/setup.md for paths.'
