#!/usr/bin/env python3
"""Offline build-policy, upload-gate and manual-tool safeguards. Never crashes/uploads."""
import importlib.util
import json
import os
from pathlib import Path
import plistlib
import subprocess
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]


def load(name, filename):
    spec = importlib.util.spec_from_file_location(name, ROOT / 'Tools' / filename)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class CrashlyticsConfigurationTests(unittest.TestCase):
    def test_project_configuration_and_required_inputs(self):
        project = json.loads(subprocess.check_output(['plutil', '-convert', 'json', '-o', '-', str(ROOT / 'Kaigi.xcodeproj/project.pbxproj')]))
        objects = project['objects']
        target = next(value for value in objects.values() if value.get('isa') == 'PBXNativeTarget' and value.get('name') == 'Kaigi')
        self.assertEqual({objects[key]['productName'] for key in target['packageProductDependencies']}, {'FirebaseCore', 'FirebaseAnalyticsCore', 'FirebaseCrashlytics'})
        packages = [value for value in objects.values() if value.get('isa') == 'XCRemoteSwiftPackageReference']
        self.assertEqual(len(packages), 1)
        self.assertEqual(packages[0]['requirement']['minimumVersion'], '13.1.1')
        phases = [objects[key] for key in target['buildPhases']]
        upload = phases[-1]
        self.assertEqual(upload['name'], 'Crashlytics symbols (opt-in archives)')
        self.assertEqual(sum('Crashlytics symbols' in value.get('name', '') for value in phases), 1)
        configs = objects[target['buildConfigurationList']]['buildConfigurations']
        for key in configs:
            settings = objects[key]['buildSettings']
            self.assertEqual(settings['DEBUG_INFORMATION_FORMAT'], 'dwarf-with-dsym')
            self.assertEqual(settings['OTHER_LDFLAGS'], ['$(inherited)', '-ObjC'])
            self.assertEqual(settings['KAIGI_CRASHLYTICS_UPLOAD_SYMBOLS'], 'NO')
            self.assertEqual(settings['KAIGI_CRASHLYTICS_VALIDATE_SYMBOLS_ONLY'], 'NO')
            self.assertNotEqual(settings.get('ENABLE_USER_SCRIPT_SANDBOXING'), 'NO')
            self.assertEqual(settings['INFOPLIST_FILE'], 'Configuration/Analytics-Info.plist')
            self.assertEqual(settings['PRODUCT_MODULE_NAME'], 'Meetrail')
            self.assertEqual(settings['PRODUCT_BUNDLE_IDENTIFIER'], 'com.volrik.kaigi')
        inputs = (ROOT / 'Configuration/Crashlytics-Release.xcfilelist').read_text().splitlines()
        self.assertEqual(len(inputs), 5)
        self.assertIn('$(TARGET_BUILD_DIR)/$(EXECUTABLE_PATH)', inputs)
        self.assertIn('$(TARGET_BUILD_DIR)/$(UNLOCALIZED_RESOURCES_FOLDER_PATH)/GoogleService-Info.plist', inputs)
        self.assertTrue(inputs[0].endswith('$(DWARF_DSYM_FILE_NAME)'))
        self.assertTrue(inputs[1].endswith('/DWARF/$(PRODUCT_NAME)'))
        self.assertTrue(inputs[2].endswith('/Contents/Info.plist'))
        debug_inputs = (ROOT / 'Configuration/Crashlytics-Debug.xcfilelist').read_text().splitlines()
        self.assertEqual(debug_inputs[:-1], inputs)
        self.assertTrue(debug_inputs[-1].endswith('$(PRODUCT_NAME).debug.dylib'))
        info = plistlib.loads((ROOT / 'Configuration/Analytics-Info.plist').read_bytes())
        self.assertIs(info['NSApplicationCrashOnExceptions'], True)
        for key in ['FirebaseAppDelegateProxyEnabled', 'FirebaseAutomaticScreenReportingEnabled', 'GOOGLE_ANALYTICS_IDFV_COLLECTION_ENABLED', 'GOOGLE_ANALYTICS_DEFAULT_ALLOW_AD_PERSONALIZATION_SIGNALS']:
            self.assertIs(info[key], False)
        pins = json.loads((ROOT / 'Kaigi.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved').read_text())
        self.assertEqual(next(pin['state']['version'] for pin in pins['pins'] if pin['identity'] == 'firebase-ios-sdk'), '13.1.1')

    def test_single_configuration_and_no_custom_crash_metadata(self):
        status = (ROOT / 'Kaigi/App/StatusController.swift').read_text()
        self.assertEqual(status.count('FirebaseApp.configure()'), 1)
        self.assertIn('AnalyticsLaunchPolicy.usesLiveAnalytics', status)
        self.assertLess(status.index('FirebaseApp.configure()'), status.index('firebaseAnalytics.configurationDidComplete()'))
        sources = [path.read_text() for path in (ROOT / 'Kaigi').rglob('*.swift')]
        self.assertEqual(sum(source.count('FirebaseApp.configure()') for source in sources), 1)
        for source in sources:
            self.assertNotIn('import FirebaseCrashlytics', source)
            self.assertNotIn('Crashlytics.crashlytics()', source)
        manual = (ROOT / 'Tools/crashlytics-verify-manually.py').read_text()
        self.assertIn('signal.SIGABRT', manual)
        # Its marker is outside every synchronized app source group.
        self.assertFalse(any('CRASH KAIGI DISPOSABLE SESSION' in path.read_text() for path in (ROOT / 'Kaigi').rglob('*.swift')))

    def test_upload_gates_never_invoke_a_real_uploader(self):
        with tempfile.TemporaryDirectory(prefix='kaigi-upload-policy-') as folder:
            sdk = Path(folder)
            (sdk / 'Crashlytics').mkdir()
            marker = sdk / 'invoked'
            for name in ['run', 'upload-symbols']:
                tool = sdk / 'Crashlytics' / name
                tool.write_text('#!/bin/sh\nprintf "%s\\n" "$@" > "$TEST_MARKER"\n')
                tool.chmod(0o755)
            cases = [
                ({'CONFIGURATION': 'Debug', 'ACTION': 'build'}, False),
                ({'CONFIGURATION': 'Debug', 'ACTION': 'install', 'KAIGI_CRASHLYTICS_UPLOAD_SYMBOLS': 'YES'}, False),
                ({'CONFIGURATION': 'Release', 'ACTION': 'build', 'KAIGI_CRASHLYTICS_UPLOAD_SYMBOLS': 'YES'}, False),
                ({'CONFIGURATION': 'Release', 'ACTION': 'install'}, False),
                ({'CONFIGURATION': 'Release', 'ACTION': 'install', 'KAIGI_CRASHLYTICS_UPLOAD_SYMBOLS': 'YES', 'XCTestBundlePath': 'synthetic'}, False),
                ({'CONFIGURATION': 'Release', 'ACTION': 'install', 'KAIGI_CRASHLYTICS_UPLOAD_SYMBOLS': 'YES'}, True),
                ({'CONFIGURATION': 'Debug', 'ACTION': 'build', 'KAIGI_CRASHLYTICS_VALIDATE_SYMBOLS_ONLY': 'YES'}, True),
            ]
            for overrides, invoked in cases:
                marker.unlink(missing_ok=True)
                # Clean environment: parent shells cannot accidentally enable upload.
                environment = {'PATH': os.environ['PATH'], 'FIREBASE_SPM_CHECKOUT_DIR': str(sdk), 'TEST_MARKER': str(marker), **overrides}
                result = subprocess.run(['/bin/sh', str(ROOT / 'Tools/upload-crashlytics-symbols.sh')], env=environment, capture_output=True)
                self.assertEqual(marker.exists(), invoked)
                if overrides.get('KAIGI_CRASHLYTICS_VALIDATE_SYMBOLS_ONLY') == 'YES':
                    self.assertEqual(marker.read_text().splitlines(), ['--build-phase', '--validate'])
                if 'XCTestBundlePath' in overrides:
                    self.assertNotEqual(result.returncode, 0)
                else:
                    self.assertEqual(result.returncode, 0)

    def test_manual_tool_refuses_owner_and_automated_sessions(self):
        tool = load('crash_manual', 'crashlytics-verify-manually.py')
        with patch.object(tool.pwd, 'getpwuid', return_value=SimpleNamespace(pw_name='owner')), patch.object(tool.subprocess, 'Popen') as launch:
            with self.assertRaises(ValueError):
                tool.validate_environment(Path('/unused'))
            launch.assert_not_called()
        with patch.object(tool.pwd, 'getpwuid', return_value=SimpleNamespace(pw_name=tool.ACCOUNT)), patch.object(tool.sys.stdin, 'isatty', return_value=False), patch.object(tool.subprocess, 'Popen') as launch:
            with self.assertRaises(ValueError):
                tool.validate_environment(Path('/unused'))
            launch.assert_not_called()
        with tempfile.TemporaryDirectory() as folder:
            app = Path(folder)
            (app / 'Contents').mkdir()
            (app / 'Contents/Info.plist').write_bytes(plistlib.dumps({'CFBundleIdentifier': 'com.volrik.kaigi'}))
            responses = [SimpleNamespace(stdout=b''), SimpleNamespace(stdout=plistlib.dumps({}))]
            with patch.object(tool.pwd, 'getpwuid', return_value=SimpleNamespace(pw_name=tool.ACCOUNT)), patch.object(tool.sys.stdin, 'isatty', return_value=True), patch.dict(os.environ, {}, clear=True), patch.object(tool.subprocess, 'run', side_effect=responses), patch.object(tool.subprocess, 'Popen') as launch:
                with self.assertRaises(ValueError):
                    tool.validate_environment(app)
                launch.assert_not_called()


if __name__ == '__main__':
    unittest.main()
