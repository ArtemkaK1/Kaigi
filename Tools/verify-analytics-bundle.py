#!/usr/bin/env python3
"""Inspect the actual signed app without disclosing Firebase configuration values."""
from pathlib import Path
import plistlib
import subprocess
import sys
import importlib.util

root = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('firebase_config', root / 'Tools/validate-firebase-config.py')
config_validator = importlib.util.module_from_spec(spec)
spec.loader.exec_module(config_validator)
app = Path(sys.argv[1]).resolve()
info = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
assert info['CFBundleIdentifier'] == 'com.volrik.kaigi', 'Unexpected bundle identity'
for key in ['FirebaseAppDelegateProxyEnabled', 'FirebaseAutomaticScreenReportingEnabled',
            'GOOGLE_ANALYTICS_IDFV_COLLECTION_ENABLED', 'GOOGLE_ANALYTICS_DEFAULT_ALLOW_AD_PERSONALIZATION_SIGNALS']:
    assert info.get(key) is False, f'Missing/incorrect Boolean flag: {key}'
copies = list(app.rglob('GoogleService-Info.plist'))
assert len(copies) == 1, 'Expected exactly one Firebase configuration resource'
config_validator.validate(copies[0], info['CFBundleIdentifier'])
assert plistlib.loads(copies[0].read_bytes()) == plistlib.loads((root / 'Kaigi/GoogleService-Info.plist').read_bytes()), 'Firebase configuration differs from local source'
result = subprocess.run(['codesign', '-d', '--entitlements', ':-', str(app)], capture_output=True, check=True)
entitlements = plistlib.loads(result.stdout)
assert entitlements.get('com.apple.security.app-sandbox') is True
assert entitlements.get('com.apple.security.network.client') is True
assert entitlements.get('com.apple.security.personal-information.calendars') is True
assert entitlements.get('com.apple.security.files.user-selected.read-write') is True
assert not entitlements.get('com.apple.security.network.server', False)
assert any(value.endswith('.com.volrik.kaigi') for value in entitlements.get('keychain-access-groups', [])), 'Missing app-scoped Keychain Sharing'
for binary in list((app / 'Contents/MacOS').iterdir()) + list((app / 'Contents/Frameworks').glob('*.framework/Versions/A/*')):
    if not binary.is_file():
        continue
    linked = subprocess.run(['otool', '-L', str(binary)], capture_output=True, text=True, check=True).stdout
    for forbidden in ['AdSupport', 'FirebaseRemoteConfig.framework', 'FirebaseAuth.framework', 'FirebaseFirestore.framework', 'FirebasePerformance.framework', 'GoogleAppMeasurementIdentitySupport', 'GoogleAdsOnDeviceConversion']:
        assert forbidden not in linked and forbidden not in binary.name, f'Unexpected dependency: {forbidden}'
if '--production' in sys.argv:
    assert not list(app.rglob('*.xctest')), 'Test bundle in production app'
    binary = app / 'Contents/MacOS' / info['CFBundleExecutable']
    strings = subprocess.run(['strings', str(binary)], capture_output=True, text=True, check=True).stdout
    for marker in ['--sample', '--marketing-fixtures', '--all-features', '--test-session']:
        assert marker not in strings, 'Debug selector marker in production executable'
print('PASS: bundled Firebase configuration, identity, Boolean privacy flags, signed entitlements and dependency isolation')
