import importlib.util
import shutil
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('release_version', ROOT / 'scripts/check-release-version.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class ReleaseVersionTests(unittest.TestCase):
    def test_valid_release_and_prerelease(self):
        version = (ROOT / 'VERSION').read_text().strip()
        self.assertEqual(module.validate('v' + version), version)
        self.assertEqual(module.validate('v' + version + '-rc.1'), version)

    def test_rejects_invalid_tags(self):
        for tag in ['main', 'v1.2', 'v01.1.2', 'v1.1.2-rc.0', 'v1.1.2\n', 'v1.1.2; echo nope', 'v65536.1.1']:
            with self.subTest(tag=tag), self.assertRaises(ValueError):
                module.validate(tag)

    def test_rejects_mismatched_package_version(self):
        paths = ['VERSION', 'windows/MeshDrop/MeshDrop.csproj', 'windows/MeshDrop/Package.appxmanifest',
                 'apple/MeshDropMac/project.yml', 'apple/MeshDropiOS/project.yml']
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            for path in paths:
                target = root / path
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(ROOT / path, target)
            manifest = root / paths[2]
            current = (ROOT / 'VERSION').read_text().strip()
            manifest.write_text(manifest.read_text().replace(current + '.0', '1.0.0.0'))
            with self.assertRaisesRegex(ValueError, 'MSIX'):
                module.validate('v' + current, root)


if __name__ == '__main__':
    unittest.main()
