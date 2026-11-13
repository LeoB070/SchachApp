#!/usr/bin/env python3
"""Exercise the launcher without building or opening a real app."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class StartChecks(unittest.TestCase):
    def run_start(self, *, system='Darwin', macos='15.0', swift='6.0', build_exit=0,
                  tools=True, install_tools=True, stockfish=True, brew_exit=0):
        with tempfile.TemporaryDirectory(prefix='chess start ') as temp:
            root = Path(temp)
            shutil.copyfile(ROOT / 'start.sh', root / 'start.sh')
            binaries = root / 'bin'
            binaries.mkdir()
            if tools:
                (root / 'tools-ready').touch()
            if stockfish:
                (root / 'stockfish-ready').touch()
            commands = {
                'uname': f'echo {system}',
                'sw_vers': f'echo {macos}',
                'xcrun': 'test -f tools-ready',
                'xcode-select': 'touch tools-ready' if install_tools else 'exit 1',
                'brew': ('if [ "$1" = list ]; then test -f stockfish-ready; '
                         'elif [ "$1" = install ]; then touch installed-stockfish; '
                         f'exit {brew_exit}; fi'),
                'swift': f'echo "Apple Swift version {swift}"',
                'open': 'touch opened',
            }
            for name, body in commands.items():
                file = binaries / name
                file.write_text('#!/bin/sh\n' + body + '\n')
                file.chmod(0o755)
            build = root / 'make-app.sh'
            build.write_text(f'#!/bin/sh\ntouch built\nexit {build_exit}\n')
            build.chmod(0o755)
            result = subprocess.run(['/bin/sh', str(root / 'start.sh')], cwd='/',
                env={**os.environ, 'PATH': f'{binaries}:/usr/bin:/bin'},
                input='\n', capture_output=True, text=True)
            installed = (root / 'installed-stockfish').exists()
            if stockfish:
                self.assertFalse(installed, 'Existing Stockfish should be reused')
            elif tools and swift.startswith('6') and system == 'Darwin' and int(macos.split('.')[0]) >= 14:
                self.assertTrue(installed, 'Missing Stockfish must be installed')
            return result, (root / 'built').exists(), (root / 'opened').exists()

    def test_builds_and_opens_from_another_directory_with_spaces(self):
        result, built, opened = self.run_start()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertTrue(built)
        self.assertTrue(opened)

    def test_failed_build_does_not_open_app(self):
        result, built, opened = self.run_start(build_exit=1)
        self.assertNotEqual(result.returncode, 0)
        self.assertTrue(built)
        self.assertFalse(opened)

    def test_unsupported_system_stops_before_build(self):
        result, built, opened = self.run_start(system='Linux')
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(built or opened)

    def test_old_macos_stops_before_build(self):
        result, built, opened = self.run_start(macos='13.7')
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(built or opened)

    def test_missing_tools_stops_before_build(self):
        result, built, opened = self.run_start(tools=False, install_tools=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(built or opened)
        self.assertIn('xcode-select --install', result.stdout + result.stderr)

    def test_installs_missing_tools_then_builds(self):
        result, built, opened = self.run_start(tools=False)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertTrue(built and opened)

    def test_installs_stockfish_before_build(self):
        result, built, opened = self.run_start(stockfish=False)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertTrue(built and opened)

    def test_failed_stockfish_install_stops_before_build(self):
        result, built, opened = self.run_start(stockfish=False, brew_exit=1)
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(built or opened)

    def test_old_swift_stops_before_build(self):
        result, built, opened = self.run_start(swift='5.10')
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(built or opened)


if __name__ == '__main__':
    unittest.main()
