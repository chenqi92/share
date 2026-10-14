import importlib.util
import json
import struct
import tempfile
import unittest
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('windows_package', ROOT / 'scripts/check-windows-package.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class WindowsPackageTests(unittest.TestCase):
    def package(self, path, missing_sodium=False, wrong_machine=False, external_runtime=False):
        pe = bytearray(128)
        pe[:2] = b'MZ'
        struct.pack_into('<I', pe, 0x3c, 64)
        pe[64:68] = b'PE\0\0'
        struct.pack_into('<H', pe, 68, 0x8664)
        with zipfile.ZipFile(path, 'w') as archive:
            for name in ['MeshDrop.exe', 'coreclr.dll', 'hostfxr.dll', 'Microsoft.ui.xaml.dll', 'libsodium.dll']:
                if name == 'libsodium.dll' and missing_sodium:
                    continue
                data = bytearray(pe)
                if name == 'libsodium.dll' and wrong_machine:
                    struct.pack_into('<H', data, 68, 0xaa64)
                archive.writestr(name, data)
            archive.writestr('MeshDrop.dll', b'')
            archive.writestr('resources.pri', b'')
            archive.writestr('MeshDrop.deps.json', json.dumps({'runtimeTarget': {'name': '.NETCoreApp,Version=v8.0/win-x64'}}))
            frameworks = {'framework': {'name': 'Microsoft.NETCore.App'}} if external_runtime else {
                'includedFrameworks': [{'name': 'Microsoft.NETCore.App', 'version': '8.0.0'}]}
            archive.writestr('MeshDrop.runtimeconfig.json', json.dumps({'runtimeOptions': frameworks}))

    def test_complete_portable_package(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / 'app.zip'
            self.package(path)
            module.validate(path, 'x64')

    def test_rejects_missing_or_incompatible_native_dependency(self):
        for options, message in [({'missing_sodium': True}, 'Missing runtime file: libsodium'),
                                 ({'wrong_machine': True}, 'Wrong architecture: libsodium'),
                                 ({'external_runtime': True}, 'external .NET runtime')]:
            with self.subTest(options=options), tempfile.TemporaryDirectory() as temp:
                path = Path(temp) / 'app.zip'
                self.package(path, **options)
                with self.assertRaisesRegex(ValueError, message):
                    module.validate(path, 'x64')


if __name__ == '__main__':
    unittest.main()
