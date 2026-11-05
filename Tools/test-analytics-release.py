#!/usr/bin/env python3
"""Compile the real Analytics selector in both configurations; never loads Firebase."""
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
for debug in (False, True):
    with tempfile.TemporaryDirectory(prefix='kaigi-analytics-policy-') as folder:
        temporary = Path(folder)
        main = temporary / 'main.swift'
        main.write_text('''
let flags = ["--sample", "--marketing-fixtures", "--all-features", "--test-session"]
precondition(AnalyticsLaunchPolicy.usesLiveAnalytics(arguments: [], isTesting: false))
for flag in flags {
    #if DEBUG
    precondition(!AnalyticsLaunchPolicy.usesLiveAnalytics(arguments: [flag], isTesting: false))
    #else
    precondition(AnalyticsLaunchPolicy.usesLiveAnalytics(arguments: [flag], isTesting: false))
    #endif
    precondition(!AnalyticsLaunchPolicy.usesLiveAnalytics(arguments: [flag], isTesting: true))
}
precondition(!AnalyticsLaunchPolicy.usesLiveAnalytics(arguments: [], isTesting: true))
''')
        binary = temporary / 'probe'
        subprocess.run(['xcrun', 'swiftc', '-O', '-module-cache-path', str(temporary / 'modules')]
                       + (['-D', 'DEBUG'] if debug else [])
                       + [str(root / 'Kaigi/App/AnalyticsLaunchPolicy.swift'), str(main), '-o', str(binary)], check=True)
        subprocess.run([str(binary)], check=True)
print('PASS: actual Debug/Release Analytics selectors and XCTest isolation')
