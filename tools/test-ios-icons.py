"""Validate one unambiguous modern icon family and its real PNG assets."""
import json
from pathlib import Path
import struct
import unittest

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / 'ios/Runner/Assets.xcassets/AppIcon.appiconset'


class IconTests(unittest.TestCase):
    def test_modern_icon_family_contains_distinct_default_dark_and_tinted(self):
        entries = json.loads((CATALOG / 'Contents.json').read_text())['images']
        self.assertEqual(len(entries), 3)
        modes = {}
        for entry in entries:
            self.assertEqual(entry['idiom'], 'universal')
            self.assertEqual(entry['size'], '1024x1024')
            self.assertNotIn('scale', entry)
            appearances = entry.get('appearances', [])
            mode = appearances[0]['value'] if appearances else 'default'
            self.assertNotIn(mode, modes)
            data = (CATALOG / entry['filename']).read_bytes()
            self.assertEqual(data[:8], b'\x89PNG\r\n\x1a\n')
            self.assertEqual(struct.unpack('>II', data[16:24]), (1024, 1024))
            self.assertEqual(data[25], 2, 'App icons must use opaque RGB PNG')
            modes[mode] = data
        self.assertEqual(set(modes), {'default', 'dark', 'tinted'})
        self.assertNotEqual(modes['default'], modes['dark'])


if __name__ == '__main__':
    unittest.main()
