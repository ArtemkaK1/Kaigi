import base64
import io
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

from verify_distribution import (MAC_DISTRIBUTION_INSTALLER_POLICY, installer_certificates,
                                 validate_entitlements, validate_info, verify_installer_certificate_chain,
                                 verify_package_signature, verify_payload_permissions, main)


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

    def test_readable_payload_and_framework_symlinks_pass(self):
        with tempfile.TemporaryDirectory() as temporary:
            app = Path(temporary) / "Meetrail.app"
            resources = app / "Contents/_CodeSignature"
            resources.mkdir(parents=True)
            for directory in (app, app / "Contents", resources):
                directory.chmod(0o755)
            signature = resources / "CodeResources"
            signature.write_text("synthetic signing metadata")
            signature.chmod(0o644)
            (app / "Contents/SignatureLink").symlink_to("_CodeSignature/CodeResources")
            verify_payload_permissions(app)

    def test_root_only_and_group_only_payload_files_fail_without_mutation(self):
        with tempfile.TemporaryDirectory() as temporary:
            app = Path(temporary) / "Meetrail.app"
            app.mkdir(mode=0o755)
            app.chmod(0o755)
            signature = app / "CodeResources"
            signature.write_text("synthetic signing metadata")
            for mode in (0o600, 0o640):
                signature.chmod(mode)
                with self.subTest(mode=mode), self.assertRaisesRegex(ValueError, "CodeResources.*umask 022"):
                    verify_payload_permissions(app)
                self.assertEqual(signature.stat().st_mode & 0o777, mode)

    def test_payload_directories_require_public_read_and_traversal(self):
        with tempfile.TemporaryDirectory() as temporary:
            app = Path(temporary) / "Meetrail.app"
            nested = app / "Contents"
            nested.mkdir(parents=True)
            app.chmod(0o755)
            for directory in (app, nested):
                for mode in (0o700, 0o750, 0o744, 0o711):
                    directory.chmod(mode)
                    with self.subTest(directory=directory.name, mode=mode), self.assertRaisesRegex(
                            ValueError, "not readable/traversable"):
                        verify_payload_permissions(app)
                directory.chmod(0o755)

    def test_current_and_legacy_distribution_statuses_pass(self):
        for status in ["signed by a developer certificate issued by Apple for distribution",
                       "signed by a certificate trusted by macOS",
                       "signed by a certificate trusted by Mac OS X",
                       "signed by a developer certificate issued by Apple",
                       "signed by a developer certificate issued by Apple (Development)"]:
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

    def test_untrusted_unknown_and_test_signing_statuses_fail_with_diagnostics(self):
        for status in ["no signature", "invalid signature", "revoked signature",
                       "signed by untrusted certificate", "signed by a certificate that has since expired",
                       "signed by a certificate trusted for current user", "signed by a certificate trusted on this system",
                       "signed by Apple for TestFlight (Development)", "unknown future status"]:
            details = f"Status: {status}\n1. Mac Installer Distribution: Example (WX557M9HD2)"
            with self.subTest(status=status), self.assertRaises(ValueError) as failure:
                verify_package_signature(details, "WX557M9HD2")
            self.assertIn(status, str(failure.exception))

    def test_apple_development_and_wrong_team_leaves_still_fail(self):
        status = "signed by a developer certificate issued by Apple (Development)"
        for leaf in ["Apple Development: Example (WX557M9HD2)", "Mac Developer: Example (WX557M9HD2)",
                     "Developer ID Installer: Example (WX557M9HD2)",
                     "3rd Party Mac Developer Installer: Example (OTHERTEAM1)"]:
            with self.subTest(leaf=leaf), self.assertRaisesRegex(ValueError, "leaf signature") as failure:
                verify_package_signature(f"Status: {status}\n1. {leaf}", "WX557M9HD2")
            self.assertNotIn("Example", str(failure.exception))

    def test_xar_certificate_selection_ignores_unrelated_xml_certificates(self):
        # Synthetic byte strings exercise XML selection only; no signing keys or
        # certificates are generated, and this is not live trust validation.
        encoded = base64.b64encode(b"signer bytes").decode()
        toc = (f'<xar><toc><signature><KeyInfo xmlns="http://www.w3.org/2000/09/xmldsig#">'
               f'<X509Data><X509Certificate>\n {encoded}\n</X509Certificate></X509Data>'
               f'</KeyInfo></signature><other><X509Certificate>ignored</X509Certificate></other></toc></xar>')
        self.assertEqual(installer_certificates(toc), [b"signer bytes"])
        for invalid in ['<xar><toc/></xar>', toc.replace(encoded, "invalid!"),
                        '<xar><toc><signature/><signature/></toc></xar>',
                        '<xar><toc><signature/></toc></xar>']:
            with self.subTest(toc=invalid), self.assertRaises(ValueError):
                installer_certificates(invalid)

    def test_cms_only_legacy_and_combined_xar_signatures(self):
        data = '<KeyInfo xmlns="http://www.w3.org/2000/09/xmldsig#"><X509Data>' \
               '<X509Certificate>bGVhZg==</X509Certificate><X509Certificate>cm9vdA==</X509Certificate>' \
               '</X509Data></KeyInfo>'
        legacy = f'<signature style="RSA">{data}</signature>'
        cms = f'<x-signature style="CMS">{data}</x-signature>'
        for signatures in [legacy, cms, legacy + cms, cms + legacy]:
            for namespace in ['', ' xmlns="urn:xar"']:
                with self.subTest(signatures=signatures, namespace=namespace):
                    toc = f'<xar{namespace}><toc>{signatures}</toc></xar>'
                    self.assertEqual(installer_certificates(toc), [b"leaf", b"root"])

    def test_duplicate_signatures_and_conflicting_signer_chains_fail(self):
        data = '<KeyInfo><X509Data><X509Certificate>bGVhZg==</X509Certificate></X509Data></KeyInfo>'
        legacy = f'<signature style="RSA">{data}</signature>'
        cms = f'<x-signature style="CMS">{data}</x-signature>'
        for signatures, diagnostic in [
            (legacy + legacy, "signature=2; x-signature=0"),
            (cms + cms, "signature=0; x-signature=2"),
            (legacy + cms.replace("bGVhZg==", "b3RoZXI="), "conflicting certificate chains"),
            (cms.replace("bGVhZg==", ""), "empty certificate"),
        ]:
            with self.subTest(signatures=signatures), self.assertRaises(ValueError) as failure:
                installer_certificates(f'<xar><toc>{signatures}</toc></xar>')
            self.assertIn(diagnostic, str(failure.exception))

    def test_mac_distribution_policy_is_mandatory_and_temporary_certificates_are_removed(self):
        for exit_code in (0, 1):
            paths = []

            def check_policy(command, **kwargs):
                self.assertEqual(command[:5], ["/usr/bin/security", "verify-cert", "-N", "-p",
                                               MAC_DISTRIBUTION_INSTALLER_POLICY])
                self.assertNotIn("-r", command)
                paths.extend(Path(command[index + 1]) for index, item in enumerate(command) if item == "-c")
                self.assertEqual([path.read_bytes() for path in paths], [b"leaf", b"intermediate", b"root"])
                return SimpleNamespace(returncode=exit_code, stdout=b"",
                                       stderr=b"CSSMERR_TP_NOT_TRUSTED (private certificate owner)")

            with self.subTest(exit_code=exit_code), patch("verify_distribution.run") as read_toc, \
                    patch("verify_distribution.installer_certificates", return_value=[b"leaf", b"intermediate", b"root"]), \
                    patch("verify_distribution.subprocess.run", side_effect=check_policy):
                if exit_code:
                    with self.assertRaisesRegex(ValueError, "CSSMERR_TP_NOT_TRUSTED") as failure:
                        verify_installer_certificate_chain("test.pkg")
                    self.assertNotIn("private certificate owner", str(failure.exception))
                else:
                    verify_installer_certificate_chain("test.pkg")
                read_toc.assert_called_once_with("/usr/bin/xar", "--dump-toc=-", "-f", "test.pkg")
            self.assertTrue(paths)
            self.assertTrue(all(not path.exists() for path in paths))

    def test_failed_trust_policy_stops_before_payload_verification(self):
        details = ("Status: signed by a developer certificate issued by Apple (Development)\n"
                   "1. 3rd Party Mac Developer Installer: Example (WX557M9HD2)")
        with patch("sys.argv", ["verify_distribution.py", "package", "test.pkg", "1.0", "123"]), \
                patch("sys.stdout", new_callable=io.StringIO), \
                patch("verify_distribution.subprocess.run", return_value=SimpleNamespace(
                    returncode=0, stdout=details.encode(), stderr=b"")), \
                patch("verify_distribution.verify_installer_certificate_chain", side_effect=ValueError("trust failed")) as trust, \
                patch("verify_distribution.run") as payload_command, patch("verify_distribution.verify_app") as app:
            with self.assertRaisesRegex(ValueError, "trust failed"):
                main()
            trust.assert_called_once_with("test.pkg")
            payload_command.assert_not_called()
            app.assert_not_called()

    def test_unreadable_exported_payload_stops_package_verification(self):
        details = ("Status: signed by a developer certificate issued by Apple (Development)\n"
                   "1. Mac Installer Distribution: Example (WX557M9HD2)")

        def expand(*command):
            self.assertEqual(command[:3], ("/usr/sbin/pkgutil", "--expand-full", "test.pkg"))
            app = Path(command[3]) / "component.pkg/Payload/Meetrail.app"
            app.mkdir(parents=True)
            app.chmod(0o755)
            signature = app / "CodeResources"
            signature.write_text("synthetic signing metadata")
            signature.chmod(0o600)

        with patch("sys.argv", ["verify_distribution.py", "package", "test.pkg", "1.0", "123"]), \
                patch("sys.stdout", new_callable=io.StringIO), \
                patch("verify_distribution.subprocess.run", return_value=SimpleNamespace(
                    returncode=0, stdout=details.encode(), stderr=b"")), \
                patch("verify_distribution.verify_installer_certificate_chain"), \
                patch("verify_distribution.run", side_effect=expand), \
                patch("verify_distribution.verify_app") as app:
            with self.assertRaisesRegex(ValueError, "CodeResources.*umask 022"):
                main()
            app.assert_not_called()

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
