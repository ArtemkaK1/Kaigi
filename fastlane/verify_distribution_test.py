import unittest

from verify_distribution import validate_entitlements, validate_info, verify_package_signature


class DistributionChecks(unittest.TestCase):
    def setUp(self):
        self.entitlements = {
            "com.apple.security.app-sandbox": True,
            "com.apple.security.personal-information.calendars": True,
            "com.apple.security.files.user-selected.read-write": True,
        }

    def test_missing_calendar_and_development_entitlements_fail(self):
        validate_entitlements(self.entitlements, "com.volrik.meetrail", "WX557M9HD2")
        for name, value in [("com.apple.security.personal-information.calendars", False),
                            ("com.apple.security.get-task-allow", True),
                            ("com.apple.security.cs.disable-library-validation", True),
                            ("com.apple.developer.team-identifier", "OTHERTEAM")]:
            with self.subTest(name=name), self.assertRaises(ValueError):
                validate_entitlements(dict(self.entitlements, **{name: value}), "com.volrik.meetrail", "WX557M9HD2")

    def test_current_and_legacy_distribution_statuses_pass(self):
        for status in ["signed by a developer certificate issued by Apple for distribution",
                       "signed by a certificate trusted by macOS",
                       "signed by a certificate trusted by Mac OS X"]:
            for certificate in ["3rd Party Mac Developer Installer", "Mac Installer Distribution"]:
                details = f"   Status: {status}\n   Certificate Chain:\n    1. {certificate}: Example (WX557M9HD2)\n"
                with self.subTest(status=status, certificate=certificate):
                    self.assertEqual(verify_package_signature(details, "WX557M9HD2"), status)

    def test_wrong_package_identity_fails(self):
        valid = ("Status: signed by a developer certificate issued by Apple for distribution\n"
                 "1. 3rd Party Mac Developer Installer: Example (WX557M9HD2)")
        for invalid in [valid.replace("WX557M9HD2", "OTHERTEAM"),
                        valid.replace("3rd Party Mac Developer Installer", "Developer ID Installer"),
                        valid.replace("1. 3rd", "2. 3rd"),
                        valid.replace("1. 3rd", "1. Developer ID Installer: Other (OTHERTEAM)\n2. 3rd")]:
            with self.subTest(signature=invalid), self.assertRaises(ValueError):
                verify_package_signature(invalid, "WX557M9HD2")

    def test_untrusted_unknown_and_development_statuses_fail_with_diagnostics(self):
        for status in ["no signature", "invalid signature", "revoked signature",
                       "signed by untrusted certificate", "signed by a certificate that has since expired",
                       "signed by a certificate trusted for current user", "signed by a certificate trusted on this system",
                       "signed by a developer certificate issued by Apple (Development)",
                       "signed by Apple for TestFlight (Development)", "unknown future status"]:
            details = f"Status: {status}\n1. Mac Installer Distribution: Example (WX557M9HD2)"
            with self.subTest(status=status), self.assertRaises(ValueError) as failure:
                verify_package_signature(details, "WX557M9HD2")
            self.assertIn(status, str(failure.exception))

    def test_failed_tool_and_missing_or_ambiguous_status_fail(self):
        valid = ("Status: signed by a developer certificate issued by Apple for distribution\n"
                 "1. Mac Installer Distribution: Example (WX557M9HD2)")
        with self.assertRaisesRegex(ValueError, "pkgutil exit 1"):
            verify_package_signature(valid, "WX557M9HD2", 1)
        for details in ["", valid + "\nStatus: no signature"]:
            with self.subTest(details=details), self.assertRaisesRegex(ValueError, "missing or ambiguous"):
                verify_package_signature(details, "WX557M9HD2")

    def test_wrong_version_build_or_menu_bar_behavior_fails(self):
        info = dict(CFBundleIdentifier="com.volrik.meetrail", CFBundleShortVersionString="1.0",
                    CFBundleVersion="123", LSUIElement=True, NSCalendarsFullAccessUsageDescription="Calendar access",
                    LSMinimumSystemVersion="15.0", LSApplicationCategoryType="public.app-category.productivity")
        validate_info(info, "com.volrik.meetrail", "1.0", "123")
        for name, value in [("CFBundleIdentifier", "wrong"), ("CFBundleVersion", "122"),
                            ("CFBundleShortVersionString", "2.0"), ("LSUIElement", False),
                            ("LSMinimumSystemVersion", "26.0"), ("LSApplicationCategoryType", "")]:
            with self.subTest(name=name), self.assertRaises(ValueError):
                validate_info(dict(info, **{name: value}), "com.volrik.meetrail", "1.0", "123")


if __name__ == "__main__":
    unittest.main()
