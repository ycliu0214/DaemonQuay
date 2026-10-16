"""Portable tests of the bundled modules' metadata and generic native module protocol."""
import json
import os
import pathlib
import shutil
import subprocess
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
BUILTINS = ROOT / 'Modules'


class ModuleTests(unittest.TestCase):
    def test_same_contract_both_services(self):
        for name in ('omlx', 'caddy'):
            with self.subTest(name=name):
                manifest = json.loads((BUILTINS / name / 'module.json').read_text())
                lifecycle = json.loads((BUILTINS / name / 'service.json').read_text())
                self.assertEqual(manifest['id'], name)
                self.assertEqual(manifest['apiVersion'], 1)
                self.assertEqual(lifecycle['apiVersion'], 1)
                self.assertEqual(manifest['executable'], 'module-control')
                self.assertEqual(lifecycle['launchLabel'], 'dev.daemonquay.' + name)
                self.assertIn(lifecycle['stopStrategy'], ('signal', 'commandThenSignal'))
                self.assertTrue(lifecycle['start'])
                fields = {field['key'] for field in manifest['settings']}
                variables = []
                optional = [arg for group in lifecycle.get('optionalStartArguments', []) for arg in group['arguments']]
                for arg in lifecycle['start'] + optional + lifecycle.get('preflight', []) + lifecycle.get('stopCommand', []):
                    if arg.startswith('${') and arg.endswith('}'):
                        variables.append(arg[2:-1])
                self.assertTrue(set(variables).issubset(fields))

    def test_public_default_settings(self):
        original = json.loads((ROOT / 'Config/settings.json').read_text())
        self.assertEqual(original['omlx']['port'], 8000)
        self.assertEqual(original['caddy']['port'], 8080)
        for name in ('omlx', 'caddy'):
            manifest = json.loads((BUILTINS / name / 'module.json').read_text())
            self.assertEqual({x['key'] for x in manifest['settings']}, set(original[name]))

    def test_optional_ssd_enabled_by_default(self):
        settings = json.loads((ROOT / 'Config/settings.json').read_text())['omlx']
        spec = json.loads((BUILTINS / 'omlx' / 'service.json').read_text())
        self.assertEqual(settings['ssdCacheDirectory'], '~/.omlx/cache')
        self.assertEqual(settings['ssdCacheMaxSize'], '20GB')
        self.assertNotIn('--paged-ssd-cache-dir', spec['start'])
        self.assertTrue(spec['optionalStartArguments'])

    def test_native_module_validate_protocol(self):
        binary = pathlib.Path(os.environ.get('DAEMONQUAY_TEST_MODULE_HOST', '')) if os.environ.get('DAEMONQUAY_TEST_MODULE_HOST') else None
        if binary is None or not binary.exists():
            self.skipTest('Build module host for this platform to run the integration test')
        with tempfile.TemporaryDirectory() as tmp:
            base = pathlib.Path(tmp)
            module = base / 'omlx'
            module.mkdir()
            (module / 'service.json').write_text(json.dumps({
                'apiVersion': 1, 'launchLabel': 'dev.daemonquay.omlx',
                'start': ['${executable}', '--flag', '${name}'],
                'stopStrategy': 'signal', 'portKey': 'port',
                'timeoutKey': 'shutdownTimeout',
            }))
            (base / 'settings.json').write_text(json.dumps({
                'omlx': {'executable': '/usr/bin/true', 'name': 'test', 'port': 8000, 'shutdownTimeout': 30}
            }))
            env = dict(os.environ, DAEMONQUAY_MODULE_ID='omlx',
                       DAEMONQUAY_MODULE_DIR=str(module), DAEMONQUAY_DATA_DIR=str(base))
            result = subprocess.run([str(binary), 'validate'], env=env, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertEqual(json.loads(result.stdout)['state'], 'stopped')


if __name__ == '__main__':
    unittest.main()
