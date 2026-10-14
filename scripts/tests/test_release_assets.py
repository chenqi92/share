import importlib.util
from pathlib import Path
import tempfile
import unittest
import zipfile

spec = importlib.util.spec_from_file_location('assets', Path(__file__).parents[1] / 'release-assets.py')
assets = importlib.util.module_from_spec(spec)
spec.loader.exec_module(assets)


class ReleaseAssetsTests(unittest.TestCase):
    def test_windows_only_cannot_publish(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / 'MeshDrop-v1.1.2-windows-x64.zip').write_bytes(b'zip')
            with self.assertRaisesRegex(ValueError, 'Incomplete release'):
                assets.validate_assets('v1.1.2', root)

    def test_complete_manifest_checksums_every_platform(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            for name in assets.required_assets('v1.1.2'):
                path = root / name
                if path.suffix in ('.zip', '.apk', '.aab', '.msix'):
                    with zipfile.ZipFile(path, 'w') as archive:
                        archive.writestr('payload', 'test')
                else:
                    path.write_bytes(b'test')
            result = assets.manifest('v1.1.2', root, 'source', 'recipe')
            self.assertEqual(len(result['assets']), 16)
            self.assertTrue(all(len(item['sha256']) == 64 for item in result['assets']))
            (root / 'MeshDrop-v1.1.2-android.apk').write_bytes(b'broken')
            with self.assertRaises(zipfile.BadZipFile):
                assets.validate_assets('v1.1.2', root)


if __name__ == '__main__':
    unittest.main()
