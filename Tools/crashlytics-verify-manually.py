#!/usr/bin/env python3
"""Owner-only, interactive Debug crash verification in a disposable macOS account.

This tool is outside all app targets. It is never run by tests or build phases.
Read Docs/Crashlytics.md and obtain explicit authorization before running it.
"""
import argparse
import os
from pathlib import Path
import plistlib
import pwd
import signal
import subprocess
import sys

ACCOUNT = 'kaigi-crash-qa'
LAUNCH_CONFIRMATION = 'LAUNCH KAIGI DISPOSABLE SESSION'
CRASH_CONFIRMATION = 'CRASH KAIGI DISPOSABLE SESSION'


def validate_environment(app):
    if pwd.getpwuid(os.getuid()).pw_name != ACCOUNT:
        raise ValueError('Use the dedicated disposable macOS account specified in Docs/Crashlytics.md.')
    if not sys.stdin.isatty() or os.environ.get('CI') or any(key in os.environ for key in ('XCTestConfigurationFilePath', 'XCTestBundlePath', 'DYLD_INSERT_LIBRARIES')):
        raise ValueError('Interactive non-test developer session required.')
    subprocess.run(['codesign', '--verify', '--deep', '--strict', str(app)], capture_output=True, check=True)
    info = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
    result = subprocess.run(['codesign', '-d', '--entitlements', ':-', str(app)], capture_output=True, check=True)
    entitlements = plistlib.loads(result.stdout)
    if info.get('CFBundleIdentifier') != 'com.volrik.kaigi' or entitlements.get('com.apple.security.get-task-allow') is not True:
        raise ValueError('A signed development Debug Kaigi build is required; Release is forbidden.')
    if not (app / 'Contents/MacOS/Kaigi.debug.dylib').is_file():
        raise ValueError('The current Xcode Debug dylib is required; Release is forbidden.')
    store = Path.home() / 'Library/Containers/com.volrik.kaigi/Data/Library/Application Support/default.store'
    if any(store.parent.glob('default.store*')):
        raise ValueError('A clean disposable account with no existing note store is required.')
    if info.get('NSApplicationCrashOnExceptions') is not True:
        raise ValueError('Build the current Crashlytics integration first.')
    running = subprocess.run(['pgrep', '-u', str(os.getuid()), '-x', 'Kaigi'], capture_output=True)
    if running.returncode != 1:
        raise ValueError('Quit existing Kaigi processes in this disposable account first.')
    return app / 'Contents/MacOS' / info['CFBundleExecutable']


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('app', type=Path)
    args = parser.parse_args()
    binary = validate_environment(args.app.resolve())
    if input('Type ' + LAUNCH_CONFIRMATION + ': ') != LAUNCH_CONFIRMATION:
        sys.exit('Cancelled; nothing launched.')
    process = subprocess.Popen([str(binary)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    # No startup timer, handler, UI control or launch argument triggers a crash.
    # The developer waits for menu-bar startup, then explicitly confirms below.
    if input('After startup, type ' + CRASH_CONFIRMATION + ': ') != CRASH_CONFIRMATION:
        sys.exit('Crash cancelled; quit the disposable app normally.')
    if process.poll() is not None:
        sys.exit('The launched app already exited; no signal sent.')
    os.kill(process.pid, signal.SIGABRT)
    process.wait()
    print('Deliberate signal sent only to this tool\'s disposable Debug process. Relaunch normally, then verify Console and dSYM symbolication. Receipt is not verified by this tool.')


if __name__ == '__main__':
    try:
        main()
    except (EOFError, KeyboardInterrupt):
        sys.exit('Cancelled; quit any disposable app normally.')
    except (ValueError, OSError, subprocess.SubprocessError):
        sys.exit('Verification refused or failed. Check the prerequisites in Docs/Crashlytics.md; no private details printed.')
