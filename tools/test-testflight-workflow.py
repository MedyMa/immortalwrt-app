"""Static security contracts for the TestFlight workflow (stdlib only).

These checks inspect this workflow's step indentation and commands; they do not
replace a macOS archive/export run with real distribution credentials.
"""
import pathlib
import re
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[1]
WORKFLOW = ROOT / ".github/workflows/testflight.yml"


class TestFlightWorkflowTests(unittest.TestCase):
    def setUp(self):
        self.source = WORKFLOW.read_text(encoding="utf-8")
        self.header, step_source = self.source.split("    steps:\n", 1)
        self.steps = re.split(r"(?m)(?=^      - )", step_source)
        self.steps = [step for step in self.steps if step.strip()]

    def step(self, name):
        matches = [step for step in self.steps if step.startswith(f"      - name: {name}\n")]
        self.assertEqual(len(matches), 1, name)
        return matches[0]

    def test_secrets_are_scoped_to_the_operations_that_need_them(self):
        self.assertNotIn("secrets.", self.header)
        allowed = {
            "Import distribution identity and profile": {
                "IOS_TEAM_ID", "IOS_DISTRIBUTION_P12_BASE64",
                "IOS_DISTRIBUTION_P12_PASSWORD", "IOS_PROVISION_PROFILE_BASE64",
            },
            "Upload to App Store Connect": {
                "ASC_KEY_ID", "ASC_ISSUER_ID", "ASC_PRIVATE_KEY_BASE64",
            },
        }
        for step in self.steps:
            name_match = re.match(r"      - name: (.+)\n", step)
            name = name_match[1] if name_match else ""
            secrets = set(re.findall(r"\$\{\{ secrets\.([A-Z0-9_]+) \}\}", step))
            with self.subTest(step=name or step.splitlines()[0]):
                self.assertEqual(secrets, allowed.get(name, set()))
                if secrets:
                    # All secret references must be in the step env mapping.
                    env = re.search(r"(?m)^        env:\n((?:          [^\n]+\n)+)", step)
                    self.assertIsNotNone(env)
                    self.assertEqual(set(re.findall(r"secrets\.([A-Z0-9_]+)", env[1])), secrets)

    def test_dependency_execution_and_unsigned_archive_precede_import(self):
        archive = self.step("Build unsigned device archive")
        imported = self.step("Import distribution identity and profile")
        self.assertIn("flutter build ipa", archive)
        self.assertIn("--release", archive)
        self.assertIn("--no-codesign", archive)
        self.assertIn('--build-number="$BUILD_NUMBER"', archive)
        self.assertLess(self.steps.index(archive), self.steps.index(imported))
        for step in self.steps[self.steps.index(imported):]:
            self.assertNotRegex(step, r"\b(?:flutter|dart|pod)\s")
            self.assertNotIn("uses:", step)
        exported = self.step("Export signed device IPA")
        self.assertLess(self.steps.index(imported), self.steps.index(exported))
        self.assertIn("xcodebuild -exportArchive", exported)
        self.assertIn("-archivePath build/ios/archive/Runner.xcarchive", exported)
        self.assertIn('-exportOptionsPlist "$RUNNER_TEMP/ExportOptions.plist"', exported)
        self.assertIn("prepare-ios-signing.py", imported)

    def test_certificate_password_is_masked_before_import(self):
        step = self.step("Import distribution identity and profile")
        mask = 'echo "::add-mask::$IOS_DISTRIBUTION_P12_PASSWORD"'
        self.assertIn(mask, step)
        self.assertLess(step.index(mask), step.index("security import"))

    def test_signed_ipa_is_only_uploaded_to_app_store_connect(self):
        self.assertNotIn("actions/upload-artifact", self.source)
        upload = self.step("Upload to App Store Connect")
        self.assertIn("altool --validate-app", upload)
        self.assertIn("altool --upload-app", upload)

    def test_cleanup_is_unconditional_and_does_not_require_secrets(self):
        cleanup = self.step("Remove temporary signing material")
        self.assertIn("if: always()", cleanup)
        self.assertNotIn("env:", cleanup)
        self.assertNotIn("ASC_KEY_ID", cleanup)
        self.assertNotIn("GITHUB_ENV", self.source)
        self.assertIn("security delete-keychain", cleanup)
        for path in ("distribution.p12", "distribution.mobileprovision", "profile.plist",
                     "ExportOptions.plist", "testflight-profile-uuid", "testflight-upload"):
            self.assertIn(path, cleanup)
        self.assertIn("Provisioning Profiles/$uuid.mobileprovision", cleanup)
        self.assertIn("build/ios/ipa", cleanup)


if __name__ == "__main__":
    unittest.main()
