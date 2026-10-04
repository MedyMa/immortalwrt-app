"""Prevent ephemeral debug signatures from becoming published update APKs."""
import pathlib
import re
import base64
import hashlib
import importlib.util
import json
import tempfile
from unittest.mock import patch
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('android_signing', ROOT / 'tools/prepare-android-signing.py')
signing = importlib.util.module_from_spec(spec)
spec.loader.exec_module(signing)


class AndroidSigningWorkflowTests(unittest.TestCase):
    def setUp(self):
        self.workflow = (ROOT / '.github/workflows/build.yml').read_text()
        self.android = self.workflow.split('  android:\n', 1)[1].split('  ios:\n', 1)[0]

    def test_unsigned_release_build_precedes_secret_import(self):
        self.assertNotIn('flutter build apk --debug', self.android)
        self.assertIn('flutter build apk --release', self.android)
        self.assertLess(self.android.index('flutter build apk --release'),
                        self.android.index('ANDROID_SIGNING_BUNDLE:'))
        self.assertIn('signingConfig = null',
                      (ROOT / 'android/app/build.gradle.kts').read_text())

    def test_fixed_signing_material_is_scoped_to_sign_step(self):
        header, steps = self.android.split('    steps:\n', 1)
        self.assertNotIn('secrets.', header)
        secret_steps = [s for s in re.split(r'(?m)(?=^      - )', steps) if 'secrets.' in s]
        self.assertEqual(len(secret_steps), 1)
        self.assertIn('name: Sign Android APK', secret_steps[0])
        self.assertIn("github.event_name != 'pull_request'", secret_steps[0])
        self.assertIn('        env:\n', secret_steps[0])
        self.assertIn('prepare-android-signing.py', secret_steps[0])
        self.assertIn(' verify --verbose --print-certs ', secret_steps[0])
        self.assertIn('--key-pass "file:$RUNNER_TEMP/android-signing/key-password.txt"', secret_steps[0])

    def test_separate_artifacts_and_cleanup(self):
        self.assertIn('name: immortalwrt-android-release', self.android)
        self.assertIn('path: build/app/outputs/flutter-apk/app-stable-release.apk', self.android)
        self.assertIn('name: immortalwrt-android-unsigned-pr', self.android)
        self.assertIn('name: Remove Android signing material\n        if: always()', self.android)
        self.assertIn('rm -rf "$RUNNER_TEMP/android-signing"', self.android)


class AndroidSigningIdentityTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = pathlib.Path(self.directory.name)
        self.pin = self.root / 'certificate.sha256'
        self.pin.write_text(hashlib.sha256(b'certificate').hexdigest())
        self.bundle = json.dumps({'keystore': base64.b64encode(b'k' * 64).decode(),
                                  'password': 'test-password'})

    def test_missing_secret_never_generates_a_replacement_key(self):
        with self.assertRaisesRegex(ValueError, 'required'):
            signing.prepare('', self.root / 'identity', self.pin)
        self.assertFalse((self.root / 'identity').exists())

    def test_wrong_identity_is_rejected(self):
        with patch.object(signing.subprocess, 'run') as run:
            run.return_value.stdout = b'wrong-certificate'
            with self.assertRaisesRegex(ValueError, 'differs'):
                signing.prepare(self.bundle, self.root / 'identity', self.pin)

    def test_fixed_identity_and_password_file(self):
        with patch.object(signing.subprocess, 'run') as run:
            run.return_value.stdout = b'certificate'
            signing.prepare(self.bundle, self.root / 'identity', self.pin)
            arguments = run.call_args.args[0]
            self.assertIn('-storepass:file', arguments)
            self.assertNotIn('test-password', arguments)
            self.assertEqual((self.root / 'identity/password.txt').read_text(), 'test-password')
            self.assertEqual((self.root / 'identity/key-password.txt').read_text(), 'test-password')

    def test_invalid_secret_size_and_password_are_rejected(self):
        for config in [{'keystore': 'eA==', 'password': 'pw'},
                       {'keystore': base64.b64encode(b'k' * 64).decode(), 'password': 'pw\n'}]:
            with self.subTest(config=config):
                with self.assertRaises(ValueError):
                    signing.prepare(json.dumps(config), self.root / 'identity', self.pin)


if __name__ == '__main__':
    unittest.main()
