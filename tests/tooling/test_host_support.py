"""Functional host admission must not broaden measurement or archive claims."""
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'scripts'))
from fp_tools.runtime import ROOT, PIN, environment, command


class HostSupportTests(unittest.TestCase):
    def host(self, system, machine, *, measured=False, version=PIN):
        calls = []
        def output(argv, **kwargs):
            calls.append(argv)
            if argv == ['mojo', '--version']:
                return version
            return 'synthetic metadata'
        with patch('fp_tools.runtime.platform.system', return_value=system), \
                patch('fp_tools.runtime.platform.machine', return_value=machine), \
                patch('fp_tools.runtime.platform.platform', return_value=f'{system}-{machine}'), \
                patch('fp_tools.runtime.subprocess.check_output', side_effect=output), \
                patch.object(Path, 'read_text', return_value='model name : Synthetic Linux CPU\n'):
            return environment(measured=measured), calls

    def test_functional_linux_avoids_darwin_commands(self):
        result, calls = self.host('Linux', 'x86_64')
        self.assertEqual(result['cpu'], 'Synthetic Linux CPU')
        self.assertEqual(result['compiler'], PIN)
        self.assertFalse(any(argv[0] == 'sysctl' for argv in calls))

    def test_measurements_remain_mac_only_and_pin_is_required(self):
        result, calls = self.host('Darwin', 'arm64', measured=True)
        self.assertEqual(result['machine'], 'arm64')
        self.assertIn(['sysctl', '-n', 'machdep.cpu.brand_string'], calls)
        for system, machine, measured, version in (
                ('Linux', 'x86_64', True, PIN),
                ('Linux', 'aarch64', False, PIN),
                ('Linux', 'x86_64', False, 'Mojo 1.0.0'),
                ('Darwin', 'x86_64', False, PIN)):
            with self.subTest(system=system, machine=machine, measured=measured, version=version):
                with self.assertRaises(RuntimeError):
                    self.host(system, machine, measured=measured, version=version)

    @unittest.skipUnless(sys.platform == 'linux', 'Linux resource accounting')
    def test_linux_resource_accounting_does_not_enable_historical_profile(self):
        with tempfile.TemporaryDirectory(dir=ROOT/'.cache') as name:
            result = command([sys.executable, '-c', 'print("ok")'],
                             Path(name)/'time.log', timed=True)
            self.assertEqual(result['stdout'], 'ok\n')
            self.assertGreater(result['peak_rss_bytes'], 0)
            self.assertEqual(result['command'][:2], ['/usr/bin/time', '-v'])



if __name__ == '__main__':
    unittest.main()
