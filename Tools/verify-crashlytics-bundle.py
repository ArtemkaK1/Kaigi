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
    for key in ('FirebaseCrashlyticsCollectionEnabled', 'FirebaseDataCollectionDefaultEnabled'):
        assert info.get(key, True) is True, f'Unexpected crash collection override: {key}'
    assert info['CFBundleIdentifier'] == 'com.volrik.kaigi'
    assert info['LSMinimumSystemVersion'] == '15.0'
    resources = app / 'Contents/Resources'
    manifest = plistlib.loads((resources / 'PrivacyInfo.xcprivacy').read_bytes())
    assert {
        'NSPrivacyAccessedAPIType': 'NSPrivacyAccessedAPICategoryUserDefaults',
        'NSPrivacyAccessedAPITypeReasons': ['CA92.1'],
    } in manifest['NSPrivacyAccessedAPITypes'], 'Missing Kaigi UserDefaults reason'
    sdk_manifest = resources / 'Firebase_FirebaseCrashlytics.bundle/Contents/Resources/PrivacyInfo.xcprivacy'
    crash_privacy = plistlib.loads(sdk_manifest.read_bytes())
    assert crash_privacy.get('NSPrivacyTracking') is False
    types = {item['NSPrivacyCollectedDataType'] for item in crash_privacy['NSPrivacyCollectedDataTypes']}
    assert {'NSPrivacyCollectedDataTypeCrashData', 'NSPrivacyCollectedDataTypeOtherDiagnosticData'} <= types
    binary = app / 'Contents/MacOS' / info['CFBundleExecutable']
    images = [binary]
    debug_dylib = binary.with_name(binary.name + '.debug.dylib')
    if debug_dylib.exists():
        images.append(debug_dylib)
    architectures = set()
    for image in images:
        image_uuids = uuids(image)
        dwarf = dsym / 'Contents/Resources/DWARF' / image.name
        assert dwarf.is_file(), 'Missing dSYM image'
        assert uuids(dwarf) == image_uuids, 'Binary/dSYM UUID or architecture mismatch'
        architectures.update(image_uuids)
    # Archive stripping removes the symbol table entries used by nm. The
    # Objective-C runtime still needs the Crashlytics class metadata.
    code_image = debug_dylib if debug_dylib.exists() else binary
    for arch in uuids(code_image):
        metadata = subprocess.run(['otool', '-arch', arch, '-ov', str(code_image)], capture_output=True, text=True, check=True).stdout
        assert re.search(r'^ *name +0x[0-9a-f]+ +FIRCrashlytics *$', metadata, re.MULTILINE), f'Crashlytics class not linked for {arch}'
    if production:
        assert architectures == {'arm64', 'x86_64'}, 'Expected universal macOS Release symbols'
        strings = subprocess.run(['strings', str(binary)], capture_output=True, text=True, check=True).stdout
        for marker in ['CRASH KAIGI DISPOSABLE SESSION', 'kaigi-crash-qa', 'crashlytics-verify-manually']:
            assert marker not in strings, 'Verification trigger in production executable'
    print('PASS: Crashlytics linked; exception configuration, bundled manifests and matching dSYM UUIDs (' + ', '.join(sorted(architectures)) + ')')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('app', type=Path)
    parser.add_argument('dsym', type=Path)
    parser.add_argument('--production', action='store_true')
    args = parser.parse_args()
    verify(args.app, args.dsym, args.production)
