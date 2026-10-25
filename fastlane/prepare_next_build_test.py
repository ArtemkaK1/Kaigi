from pathlib import Path
import re
import subprocess
import sys
import tempfile
import unittest

from prepare_next_build import updated_project


class NextBuildNumberPreparation(unittest.TestCase):
    def setUp(self):
        project = (Path(__file__).resolve().parents[1] / "Meetrail.xcodeproj/project.pbxproj").read_text()
        # Future bot commits must not change the meaning of the regression fixtures.
        self.source = re.sub(r"(?m)^([\t ]*CURRENT_PROJECT_VERSION = )[0-9]+;", r"\g<1>1;", project)

    def test_updates_only_app_debug_and_release_settings(self):
        updated, _ = updated_project(self.source, "40185690362002", "1.0")
        before = self.source.splitlines()
        after = updated.splitlines()
        changes = [(old, new) for old, new in zip(before, after) if old != new]
        self.assertEqual(len(before), len(after))
        self.assertEqual(len(changes), 2)
        self.assertTrue(all(old.strip().startswith("CURRENT_PROJECT_VERSION = ") and
                            new.strip() == "CURRENT_PROJECT_VERSION = 40185690362003;" for old, new in changes))
        self.assertEqual(updated.count("MARKETING_VERSION = 1.0;"), self.source.count("MARKETING_VERSION = 1.0;"))

    def test_uploaded_build_one_prepares_build_two(self):
        updated, message = updated_project(self.source, "1", "1.0")
        self.assertEqual(updated.count("CURRENT_PROJECT_VERSION = 2;"), 2)
        self.assertEqual(updated.count("CURRENT_PROJECT_VERSION = 1;"), 4)
        self.assertIn("next build number: 2", message)

    def test_idempotence_and_no_downgrade_on_old_job_reruns(self):
        updated, _ = updated_project(self.source, "40185690362003", "1.0")
        self.assertEqual(updated_project(updated, "40185690362003", "1.0")[0], updated)
        self.assertEqual(updated_project(updated, "40185690362002", "1.0")[0], updated)

    def test_changed_marketing_version_or_unexpected_project_layout_fails(self):
        for source in [self.source.replace("MARKETING_VERSION = 1.0;", "MARKETING_VERSION = 1.1;"),
                       self.source.replace('configuration for PBXNativeTarget "Meetrail"',
                                           'configuration for PBXNativeTarget "Renamed"'),
                       self.source.replace("CURRENT_PROJECT_VERSION = ", "RENAMED_SETTING = ")]:
            with self.subTest(source=source[:50]), self.assertRaises(ValueError):
                updated_project(source, "40185690362002", "1.0")

    def test_rejects_invalid_outputs(self):
        for number, version in [("", "1.0"), ("1\nOTHER=2", "1.0"), ("-1", "1.0"),
                                ("1.2", "1.0"), ("1" * 19, "1.0"), ("9" * 18, "1.0"),
                                ("2", "1.0\nOTHER=2")]:
            with self.subTest(number=number, version=version), self.assertRaises(ValueError):
                updated_project(self.source, number, version)

    def test_cli_writes_only_valid_updates_and_leaves_file_intact_on_failure(self):
        with tempfile.TemporaryDirectory() as directory:
            project = Path(directory) / "project.pbxproj"
            project.write_text(self.source)
            script = Path(__file__).with_name("prepare_next_build.py")
            result = subprocess.run([sys.executable, str(script), str(project), "40185690362002", "1.0"],
                                    capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            expected = updated_project(self.source, "40185690362002", "1.0")[0]
            self.assertEqual(project.read_text(), expected)
            result = subprocess.run([sys.executable, str(script), str(project), "40185690362003", "1.1"],
                                    capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(project.read_text(), expected)


if __name__ == "__main__":
    unittest.main()
