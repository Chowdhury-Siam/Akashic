"""Exercise GUI polling with a busy installer without requiring Windows."""
import ctypes as C
import unittest
from unittest.mock import patch

import check_windows_gui as gui


class User32Fixture:
    def __init__(self, phase="INSTALLING YUTAKA", path_responds=False):
        # Enumeration reaches the edit before the status label, just as in CI.
        self.controls = {
            10: ("TNewPathEdit", ""),
            20: ("TNewStaticText", phase),
        }
        self.path_responds = path_responds
        self.messages = []

    def GetClassNameW(self, handle, value, size):
        value.value = self.controls[handle][0]
        return len(value.value)

    def GetWindowTextW(self, handle, value, size):
        value.value = self.controls[handle][1]
        return len(value.value)

    def SendMessageTimeoutW(self, handle, message, wparam, lparam, flags, timeout, result):
        self.messages.append((handle, message))
        if not self.path_responds:
            return 0
        path = "C:\\My Apps\\Yutaka"
        C.memmove(lparam, C.create_unicode_buffer(path), C.sizeof(C.create_unicode_buffer(path)))
        C.cast(result, C.POINTER(C.c_size_t))[0] = len(path)
        return 1

    def IsWindowEnabled(self, handle):
        return True

    def GetWindowLongW(self, handle, index):
        return 0x54000000


class WindowsGuiPollingTest(unittest.TestCase):
    def setUp(self):
        self.fixture = User32Fixture()
        # Only __init__ binds the actual Windows DLL; exercise the real methods.
        self.api = gui.Windows.__new__(gui.Windows)
        self.api.api = self.fixture
        self.api.windows = lambda parent=None: list(self.fixture.controls)

    def test_completion_lookup_does_not_query_busy_path_edit(self):
        self.fixture.controls[20] = ("TNewStaticText", "INSTALLATION COMPLETE")
        self.assertEqual(self.api.control(1, "INSTALLATION COMPLETE"), 20)
        self.assertEqual(self.fixture.messages, [])

    def test_busy_installation_can_be_polled_until_completion(self):
        def finish_installation(_):
            self.fixture.controls[20] = ("TNewStaticText", "INSTALLATION COMPLETE")

        with patch.object(gui.time, "sleep", side_effect=finish_installation):
            result = gui.wait_for(lambda: self.api.control(1, "INSTALLATION COMPLETE"),
                                  "Install did not complete", timeout=1)
        self.assertEqual(result, 20)
        self.assertEqual(self.fixture.messages, [])

    def test_missing_completion_still_fails_at_overall_deadline(self):
        with patch.object(gui.time, "monotonic", side_effect=[0, 0, 2]), \
                patch.object(gui.time, "sleep"):
            with self.assertRaisesRegex(AssertionError, "Install did not complete"):
                gui.wait_for(lambda: self.api.control(1, "INSTALLATION COMPLETE"),
                             "Install did not complete", timeout=1)
        self.assertEqual(self.fixture.messages, [])

    def test_failure_dump_does_not_query_busy_path_edit(self):
        output = self.api.dump(1)
        self.assertIn("TNewPathEdit", output)
        self.assertIn("INSTALLING YUTAKA", output)
        self.assertIn("style=0x54000000", output)
        self.assertEqual(self.fixture.messages, [])

    def test_explicit_path_read_still_checks_response(self):
        with self.assertRaisesRegex(AssertionError, "Install location did not respond"):
            self.api.text(10)
        self.assertEqual(self.fixture.messages, [(10, 0x000D)])

    def test_explicit_path_read_returns_edit_contents(self):
        self.fixture.path_responds = True
        self.assertEqual(self.api.text(10), "C:\\My Apps\\Yutaka")
        self.assertEqual(self.fixture.messages, [(10, 0x000D)])


if __name__ == "__main__":
    unittest.main()
