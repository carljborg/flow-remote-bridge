#!/usr/bin/env python3
"""Build/install a receiver or macOS client in the current user's account."""
import argparse
import os
from pathlib import Path
import plistlib
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
HOME = Path.home()
DOMAIN = f'gui/{os.getuid()}'


def run(*args):
    subprocess.run([str(arg) for arg in args], check=True)


def agent(label, arguments):
    path = HOME / 'Library/LaunchAgents' / (label + '.plist')
    path.parent.mkdir(parents=True, exist_ok=True)
    logs = HOME / 'Library/Logs/FlowRemoteBridge'
    logs.mkdir(parents=True, exist_ok=True)
    data = dict(Label=label, ProgramArguments=[str(a) for a in arguments], RunAtLoad=True,
                KeepAlive=True, ThrottleInterval=10,
                StandardOutPath=str(logs / (label + '.log')),
                StandardErrorPath=str(logs / (label + '.err.log')))
    path.write_bytes(plistlib.dumps(data))
    return path


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('role', choices=['receiver', 'client'])
    p.add_argument('--start', action='store_true', help='Load the LaunchAgent after installing')
    args = p.parse_args()
    label = 'org.flowremotebridge.' + args.role
    # Stop a previous installed instance before replacing an executable.
    subprocess.run(['launchctl', 'bootout', DOMAIN + '/' + label], capture_output=True)
    if args.role == 'receiver':
        app = HOME / 'Applications/Flow Remote Bridge.app'
        binary = app / 'Contents/MacOS/FlowRemoteReceiver'
        binary.parent.mkdir(parents=True, exist_ok=True)
        run('xcrun', 'swiftc', '-swift-version', '5', '-O', ROOT / 'receiver/Receiver.swift', '-o', binary)
        (app / 'Contents/Info.plist').write_bytes(plistlib.dumps(dict(
            CFBundleExecutable='FlowRemoteReceiver', CFBundleIdentifier=label,
            CFBundleName='Flow Remote Bridge', CFBundlePackageType='APPL',
            CFBundleShortVersionString='0.1.0', CFBundleVersion='1', LSUIElement=True)))
        run('codesign', '--force', '--sign', '-', app)
        destination = HOME / '.local/bin/flow-remote-submit'
        destination.parent.mkdir(parents=True, exist_ok=True)
        source = (ROOT / 'receiver/flow-remote-submit').read_text()
        # SSH's PATH can differ from a terminal; pin this installation's Python.
        import sys
        source = '#!' + str(Path(sys.executable).resolve()) + '\n' + source.split('\n', 1)[1]
        destination.write_text(source)
        destination.chmod(0o700)
        path = agent(label, [binary])
        print('Allow Flow Remote Bridge in System Settings → Privacy & Security → Accessibility.')
        print('The installer does not grant this permission.')
    else:
        import sys
        target = HOME / '.local/share/flow-remote-bridge'
        target.mkdir(parents=True, exist_ok=True)
        for name in ['watch.py', 'policy.py']:
            shutil.copy2(ROOT / 'clients/macos' / name, target / name)
        run('xcrun', 'swiftc', '-O', ROOT / 'clients/macos/Frontmost.swift', '-o', target / 'frontmost')
        config = HOME / '.config/flow-remote-bridge/config.json'
        config.parent.mkdir(parents=True, exist_ok=True)
        if not config.exists():
            shutil.copy2(ROOT / 'clients/macos/config.example.json', config)
        path = agent(label, [Path(sys.executable).resolve(), target / 'watch.py', '--config', config])
        print('Edit configuration before starting:', config)
    if args.start:
        run('launchctl', 'bootstrap', DOMAIN, path)
    else:
        print('Installed but not started. Start with:')
        print(f'launchctl bootstrap {DOMAIN} "{path}"')


if __name__ == '__main__':
    main()
