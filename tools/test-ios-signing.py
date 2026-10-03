import copy
import datetime
import importlib.util
import pathlib
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("signing", ROOT / "tools/prepare-ios-signing.py")
signing = importlib.util.module_from_spec(spec)
spec.loader.exec_module(signing)


class SigningTests(unittest.TestCase):
    def setUp(self):
        self.profile = {
            "TeamIdentifier": ["ABCDE12345"], "UUID": "12345678-1234-1234-1234-123456789ABC",
            "ExpirationDate": datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None) + datetime.timedelta(days=1),
            "Entitlements": {"application-identifier": "ABCDE12345.com.medyma.immortalwrtApp", "get-task-allow": False},
        }

    def run_prepare(self, profile):
        with tempfile.TemporaryDirectory() as directory:
            project = pathlib.Path(directory) / "project.pbxproj"
            project.write_bytes((ROOT / "ios/Runner.xcodeproj/project.pbxproj").read_bytes())
            original = project.read_text()
            signing.prepare(profile, "ABCDE12345", project, pathlib.Path(directory) / "export.plist")
            result = project.read_text()
            self.assertEqual(result.count("DEVELOPMENT_TEAM = ABCDE12345;"), 3)
            self.assertEqual(result.count("com.medyma.immortalwrtApp.RunnerTests;"), original.count("com.medyma.immortalwrtApp.RunnerTests;"))

    def test_distribution_profile(self):
        self.run_prepare(self.profile)

    def test_reject_wrong_team_bundle_development_or_expired_profile(self):
        cases = [
            {"TeamIdentifier": ["WRONG12345"]},
            {"ExpirationDate": datetime.datetime(2020, 1, 1)},
            {"ProvisionedDevices": ["some-device"]},
            {"Entitlements": {"application-identifier": "ABCDE12345.wrong", "get-task-allow": False}},
            {"Entitlements": {"application-identifier": "ABCDE12345.com.medyma.immortalwrtApp", "get-task-allow": True}},
        ]
        for change in cases:
            with self.subTest(change=change), self.assertRaises(ValueError):
                profile = copy.deepcopy(self.profile)
                profile.update(change)
                self.run_prepare(profile)


if __name__ == "__main__":
    unittest.main()
