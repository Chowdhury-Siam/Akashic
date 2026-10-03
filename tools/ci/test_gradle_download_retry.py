"""Exercise the workflow's actual retry shell without downloading Gradle."""

import os
from pathlib import Path
import subprocess
import tempfile
import unittest


class GradleDownloadRetryTest(unittest.TestCase):
    def test_success_recovery_and_bounded_failure(self):
        workflow = (
            Path(__file__).resolve().parents[2]
            / '.github/workflows/build-android-apks.yml'
        ).read_text()
        step = workflow.split('      - name: Download Gradle with bounded retries\n', 1)[1]
        step = step.split('\n      - name:', 1)[0]
        script = '\n'.join(
            line[10:] for line in step.split('        run: |\n', 1)[1].splitlines()
        )
        self.assertIn('timeout --kill-after=10s 180s ./gradlew --version', script)

        for failures, attempts, exit_code, delays in [
            (0, 1, 0, []),
            (2, 3, 0, ['5', '10']),
            (10, 4, 1, ['5', '10', '15']),
        ]:
            with self.subTest(failures=failures), tempfile.TemporaryDirectory() as folder:
                root = Path(folder)
                commands = {
                    'gradlew': '''#!/bin/bash
set -eu
test "$*" = '--version'
count=0
if [ -f attempts ]; then count=$(cat attempts); fi
count=$((count + 1))
echo "$count" > attempts
if [ "$count" -le "$FAILURES" ]; then exit 1; fi
''',
                    'timeout': '#!/bin/bash\nshift 2\nexec "$@"\n',
                    'sleep': '#!/bin/bash\necho "$1" >> delays\n',
                }
                for name, content in commands.items():
                    path = root / name
                    path.write_text(content)
                    path.chmod(0o755)
                env = dict(os.environ, PATH=f'{root}{os.pathsep}{os.environ["PATH"]}', FAILURES=str(failures))
                result = subprocess.run(
                    ['bash', '-c', script], cwd=root, env=env,
                    capture_output=True, text=True, timeout=5,
                )
                self.assertEqual(result.returncode, exit_code, result.stdout + result.stderr)
                self.assertEqual(int((root / 'attempts').read_text()), attempts)
                delay_file = root / 'delays'
                self.assertEqual(delay_file.read_text().splitlines() if delay_file.exists() else [], delays)


if __name__ == '__main__':
    unittest.main()
