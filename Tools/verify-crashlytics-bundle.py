#!/usr/bin/env python3
"""Offline Crashlytics linkage and dSYM UUID verification. Never uploads symbols."""
import argparse
from pathlib import Path
import plistlib
import re
import subprocess


def uuids(path):
    result = subprocess.run(['xcrun', 'dwarfdump', '--uuid', str(path)], capture_output=True, text=True, check=True)
    values = re.findall(r'UUID: ([0-9A-Fa-f-]+) \(([^)]+)\)', result.stdout)
    assert values, 'No Mach-O UUIDs found'
    return {arch: uuid.upper() for uuid, arch in values}


def verify(app, dsym, production=False):
    info = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
    assert info.get('NSApplicationCrashOnExceptions') is True, 'Missing macOS exception Boolean'
    assert info.get('FirebaseCrashlyticsCollectionEnabled') is not False, 'Live fatal crash collection disabled'
    assert info['CFBundleIdentifier'] == 'com.volrik.kaigi'
    assert info['LSMinimumSystemVersion'] == '15.0'
    binary = app / 'Contents/MacOS' / info['CFBundleExecutable']
    images = [binary]
    debug_dylib = binary.with_name(binary.name + '.debug.dylib')
    if debug_dylib.exists():
        images.append(debug_dylib)
    # Crashlytics is a static SPM product: inspecting only otool's dylib list misses it.
    symbols = '\n'.join(subprocess.run(['nm', '-m', str(image)], capture_output=True, text=True, check=True).stdout for image in images)
    assert any('_OBJC_CLASS_$_FIRCrashlytics' in line and '(undefined)' not in line for line in symbols.splitlines()), 'Crashlytics class not linked'
    architectures = set()
    for image in images:
        image_uuids = uuids(image)
        dwarf = dsym / 'Contents/Resources/DWARF' / image.name
        assert dwarf.is_file(), 'Missing dSYM image'
        assert uuids(dwarf) == image_uuids, 'Binary/dSYM UUID or architecture mismatch'
        architectures.update(image_uuids)
    if production:
        assert architectures == {'arm64', 'x86_64'}, 'Expected universal macOS Release symbols'
        strings = subprocess.run(['strings', str(binary)], capture_output=True, text=True, check=True).stdout
        for marker in ['CRASH KAIGI DISPOSABLE SESSION', 'kaigi-crash-qa', 'crashlytics-verify-manually']:
            assert marker not in strings, 'Verification trigger in production executable'
    print('PASS: Crashlytics linked; exception configuration and matching dSYM UUIDs (' + ', '.join(sorted(architectures)) + ')')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('app', type=Path)
    parser.add_argument('dsym', type=Path)
    parser.add_argument('--production', action='store_true')
    args = parser.parse_args()
    verify(args.app, args.dsym, args.production)
