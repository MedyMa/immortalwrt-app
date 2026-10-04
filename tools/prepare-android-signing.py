"""Import the fixed Android identity after all dependency build scripts finish."""
import base64
import hashlib
import json
import os
import pathlib
import subprocess
import sys


def prepare(bundle, destination, expected_certificate):
    if not bundle:
        raise ValueError('ANDROID_SIGNING_BUNDLE is required; never generate a CI identity')
    config = json.loads(bundle)
    password = config.get('password')
    if not isinstance(password, str) or not password or any(c in password for c in '\r\n'):
        raise ValueError('Invalid Android signing password')
    keystore = base64.b64decode(config['keystore'], validate=True)
    if not 16 <= len(keystore) <= 262144:
        raise ValueError('Invalid Android keystore size')
    expected = expected_certificate.read_text().strip().lower()
    if len(expected) != 64 or any(c not in '0123456789abcdef' for c in expected):
        raise ValueError('Invalid pinned Android signing certificate')
    destination.mkdir(mode=0o700, parents=True, exist_ok=True)
    destination.chmod(0o700)
    for name, data in [('key.jks', keystore), ('password.txt', password.encode())]:
        with os.fdopen(os.open(destination / name, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600), 'wb') as output:
            output.write(data)
        (destination / name).chmod(0o600)
    certificate = subprocess.run([
        'keytool', '-exportcert', '-keystore', str(destination / 'key.jks'),
        '-storepass:file', str(destination / 'password.txt'), '-alias', 'immortalwrt',
    ], check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE).stdout
    if hashlib.sha256(certificate).hexdigest() != expected:
        raise ValueError('Android signing identity differs from the pinned certificate')


if __name__ == '__main__':
    root = pathlib.Path(__file__).resolve().parents[1]
    prepare(os.environ.get('ANDROID_SIGNING_BUNDLE'), pathlib.Path(sys.argv[1]),
            root / 'android/signing-certificate.sha256')
    print('Fixed Android signing identity verified')
