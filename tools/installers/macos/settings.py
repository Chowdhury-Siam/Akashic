"""Finder layout for the branded, universal Yutaka disk image."""
import os
import plistlib
from pathlib import Path

application = Path(os.environ["YUTAKA_MACOS_APP"]).resolve()
with (application / "Contents/Info.plist").open("rb") as stream:
    info = plistlib.load(stream)
icon_name = info.get("CFBundleIconFile", "AppIcon.icns")
if not Path(icon_name).suffix:
    icon_name += ".icns"
icon = str(application / "Contents/Resources" / icon_name)
if not Path(icon).is_file():
    raise FileNotFoundError(f"App icon is missing: {icon}")

format = "UDZO"
compression_level = 1
files = [(str(application), "Yutaka.app")]
symlinks = {"Applications": "/Applications"}
hide_extension = ["Yutaka.app"]
background = str(Path(os.environ["YUTAKA_INSTALLER_ASSETS"]).resolve() / "macos-background.png")
window_rect = ((160, 140), (720, 440))
default_view = "icon-view"
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
include_icon_view_settings = True
include_list_view_settings = False
icon_locations = {"Yutaka.app": (210, 246), "Applications": (510, 246)}
icon_size = 104
text_size = 14
label_pos = "bottom"
arrange_by = None
grid_offset = (0, 0)
grid_spacing = 100
