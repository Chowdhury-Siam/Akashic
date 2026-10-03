"""Exercise GUI polling and styled-control input without requiring Windows."""
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

    def test_failure_dump_includes_installer_error_dialog(self):
        self.fixture.controls.update({1: ("TWizardForm", "Yutaka setup"),
                                      2: ("#32770", "Setup error"),
                                      3: ("Static", "The folder could not be opened")})
        self.api.windows = lambda parent=None: {None: [1, 2, 999],
                                                1: [10, 20], 2: [3]}[parent]
        self.api.pid = lambda handle: 5 if handle != 999 else 6
        output = self.api.dump_related(1)
        self.assertIn("Yutaka setup", output)
        self.assertIn("Setup error", output)
        self.assertIn("The folder could not be opened", output)
        self.assertEqual(self.fixture.messages, [])

    def test_explicit_path_read_still_checks_response(self):
        with self.assertRaisesRegex(AssertionError, "Install location did not respond"):
            self.api.text(10)
        self.assertEqual(self.fixture.messages, [(10, 0x000D)])

    def test_explicit_path_read_returns_edit_contents(self):
        self.fixture.path_responds = True
        self.assertEqual(self.api.text(10), "C:\\My Apps\\Yutaka")
        self.assertEqual(self.fixture.messages, [(10, 0x000D)])


class StyledControlsFixture(User32Fixture):
    """A styled button requires activation, hover and a completed mouse press."""
    def __init__(self):
        super().__init__(phase="INSTALLATION NOT STARTED")
        self.controls.update({30: ("TNewButton", "Install Yutaka"),
                              40: ("TNewCheckBox", "Create a desktop shortcut"),
                              50: ("TNewStaticText", "TEST DESKTOP SHORTCUT: 1")})
        self.bounds = {30: (767, 560, 146, 48), 40: (292, 384, 610, 24)}
        self.foreground = None
        self.activate = True
        self.cursor = (0, 0)
        self.pressed = None
        self.desktop_selected = True
        self.shortcut_created = None
        self.queued = []
        self.input_events = []
        self.native_pending = False

    def GetAncestor(self, handle, flag):
        return 1

    def SetForegroundWindow(self, handle):
        if self.activate:
            self.foreground = handle
        return self.activate

    def GetForegroundWindow(self):
        return self.foreground

    def GetClientRect(self, handle, pointer):
        rect = C.cast(pointer, C.POINTER(gui.W.RECT)).contents
        rect.left = rect.top = 0
        rect.right, rect.bottom = self.bounds[handle][2:]
        return 1

    def ClientToScreen(self, handle, pointer):
        point = C.cast(pointer, C.POINTER(gui.W.POINT)).contents
        point.x += self.bounds[handle][0]
        point.y += self.bounds[handle][1]
        return 1

    def SetCursorPos(self, x, y):
        self.cursor = (x, y)
        return 1

    def handle_mouse(self, handle, message, position):
        origin_x, origin_y, width, height = self.bounds[handle]
        x, y = position & 0xffff, position >> 16
        inside = (0 <= x < width and 0 <= y < height and
                  self.cursor == (origin_x + x, origin_y + y) and self.foreground == 1)
        if message == 0x0201 and inside:
            self.pressed = handle
        if message == 0x0202:
            if self.pressed == handle and inside:
                if handle == 30:
                    self.shortcut_created = self.desktop_selected
                    self.controls[20] = ("TNewStaticText", "INSTALLATION COMPLETE")
            self.pressed = None

    def SendMessageTimeoutW(self, handle, message, wparam, lparam, flags, timeout, result):
        self.messages.append((handle, message))
        self.handle_mouse(handle, message, lparam)
        return 1

    def PostMessageW(self, handle, message, wparam, lparam):
        self.queued.append((handle, message, lparam))
        return 1

    def SendInput(self, count, events, size):
        self.input_events.extend((events[i].type, events[i].payload.mouse.dwFlags)
                                 for i in range(count))
        self.native_pending = True
        return count

    def dispatch_native(self, _=None):
        if self.native_pending:
            self.native_pending = False
            self.desktop_selected = not self.desktop_selected
            self.controls[50] = ("TNewStaticText", "TEST DESKTOP SHORTCUT: " + str(int(self.desktop_selected)))

    def dispatch_queued(self):
        for handle, message, position in self.queued:
            # A plain BM_CLICK does not supply the styled control's hover path.
            if message != 0x00F5:
                self.handle_mouse(handle, message, position)
        self.queued.clear()


class WindowsGuiClickTest(unittest.TestCase):
    def setUp(self):
        self.fixture = StyledControlsFixture()
        self.api = gui.Windows.__new__(gui.Windows)
        self.api.api = self.fixture
        self.api.windows = lambda parent=None: list(self.fixture.controls)

    def test_install_button_receives_click_after_modal_focus_loss(self):
        self.api.click(30)
        # The release must stay asynchronous: Install may enter synchronous work.
        self.assertEqual(self.fixture.controls[20][1], "INSTALLATION NOT STARTED")
        self.assertEqual(self.fixture.foreground, 1)
        self.assertEqual(self.fixture.cursor, (840, 584))
        self.fixture.dispatch_queued()
        self.assertEqual(self.fixture.controls[20][1], "INSTALLATION COMPLETE")

    def test_checkbox_finishes_before_install_moves_cursor(self):
        with patch.object(gui.time, "sleep", side_effect=self.fixture.dispatch_native):
            self.api.click_checkbox(40, selected=False)
        self.assertFalse(self.fixture.desktop_selected)
        self.assertEqual(self.fixture.input_events, [(0, 0x0002), (0, 0x0004)])
        self.assertEqual(self.fixture.cursor, (304, 396))
        self.api.click(30)
        self.fixture.dispatch_queued()
        self.assertEqual(self.fixture.controls[20][1], "INSTALLATION COMPLETE")
        self.assertFalse(self.fixture.shortcut_created)

    def test_checkbox_selection_creates_shortcut(self):
        self.fixture.desktop_selected = False
        self.fixture.controls[50] = ("TNewStaticText", "TEST DESKTOP SHORTCUT: 0")
        with patch.object(gui.time, "sleep", side_effect=self.fixture.dispatch_native):
            self.api.click_checkbox(40, selected=True)
        self.api.click(30)
        self.fixture.dispatch_queued()
        self.assertTrue(self.fixture.shortcut_created)

    def test_injected_click_without_state_change_fails_before_install(self):
        with patch.object(gui.time, "monotonic", side_effect=[0, 0, 0, 0, 6]), \
                patch.object(gui.time, "sleep"):
            with self.assertRaisesRegex(AssertionError, "checkbox did not change"):
                self.api.click_checkbox(40, selected=False)
        self.assertIsNone(self.fixture.shortcut_created)

    def test_partial_input_injection_fails_before_install(self):
        with patch.object(self.fixture, "SendInput", return_value=1):
            with self.assertRaisesRegex(AssertionError, "was not injected"):
                self.api.click_checkbox(40, selected=False)
        self.assertIsNone(self.fixture.shortcut_created)

    def test_input_structure_has_win32_size_and_alignment(self):
        is_64_bit = C.sizeof(C.c_void_p) == 8
        self.assertEqual(C.sizeof(gui.Input), 40 if is_64_bit else 28)
        self.assertEqual(gui.Input.payload.offset, 8 if is_64_bit else 4)

    def test_unavailable_foreground_fails_before_mouse_input(self):
        self.fixture.activate = False
        with patch.object(gui.time, "monotonic", side_effect=[0, 0, 6]), \
                patch.object(gui.time, "sleep"):
            with self.assertRaisesRegex(AssertionError, "activate"):
                self.api.click(30)
        self.assertEqual(self.fixture.messages, [])
        self.assertEqual(self.fixture.queued, [])

    def test_unresponsive_mouse_handler_does_not_post_release(self):
        with patch.object(self.fixture, "SendMessageTimeoutW", return_value=0):
            with self.assertRaisesRegex(AssertionError, "did not process mouse"):
                self.api.click(30)
        self.assertEqual(self.fixture.queued, [])


if __name__ == "__main__":
    unittest.main()
