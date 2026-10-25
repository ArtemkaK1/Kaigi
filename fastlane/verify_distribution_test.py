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

    def test_wrong_package_identity_fails(self):
        valid = "Status: signed by a certificate trusted by macOS\n1. 3rd Party Mac Developer Installer: Example (WX557M9HD2)"
        verify_package_signature(valid, "WX557M9HD2")
        for invalid in [valid.replace("WX557M9HD2", "OTHERTEAM"),
                        valid.replace("3rd Party Mac Developer Installer", "Developer ID Installer"),
                        valid.replace("trusted by", "not trusted by")]:
            with self.subTest(signature=invalid), self.assertRaises(ValueError):
                verify_package_signature(invalid, "WX557M9HD2")

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
