# Yutaka desktop installers

The artwork uses the real `assets/icons/app_icon.png`, charcoal background
`#0F1216`, surface `#13181D`, outline `#272F35`, muted text `#ADB5BB`, and
Yutaka green `#00BD91`, matching `lib/app_config.dart`.

Actual Linux installer preview:

![Yutaka Linux installer](../../docs/images/yutaka-linux-installer.png)

- **Windows:** `windows/yutaka.iss` uses Inno Setup 6.7+ native dark controls,
  high contrast support, branded wizard artwork, standard folder/shortcut/progress
  pages, and the existing stable app ID. CI signs the executable before packaging
  and the setup file afterward when certificates are configured.
- **Linux:** `linux/setup.c` provides a GTK 3 screen with the app icon, rounded
  cards, green action button, folder selector, optional desktop shortcut, animated
  activity and progress. `linux/install.sh` installs the bundled AppImage for the
  current user and replaces it atomically; it never deletes app data or the chosen
  folder. `linux/build.py` embeds the UI, backend and AppImage in a self-extracting
  `.run` file with a SHA-256 corruption check. GTK 3 is only needed for the GUI;
  Bash, tar and sha256sum are required for terminal setup. The normal AppImage and
  portable archive remain available, and in-app updates still use the AppImage.
- **macOS:** `macos/settings.py` provides the Finder window layout, real volume
  icon and Applications link. CI uses pinned dmgbuild, packaging the signed app
  intact. Finder provides the copy progress during drag-to-Applications install.

Generated artwork is checked in, so release runners need no image-rendering
dependencies. To regenerate it, install Pillow and Inter or DejaVu Sans, then run:

```bash
python3 tools/installers/render_branding.py
```

Run installer regression tests without Flutter:

```bash
python3 -m unittest discover -s tools/installers/tests -p 'test_*.py' -v
```

Build and check the native Linux UI on a machine with GTK 3 development packages,
GCC, pkg-config, Xvfb and xauth:

```bash
gcc -std=c11 -O2 -Wall -Wextra -Werror tools/installers/linux/setup.c \
  -o /tmp/yutaka-setup $(pkg-config --cflags --libs gtk+-3.0 gio-2.0)
mkdir -p /tmp/yutaka-setup-payload
cp assets/icons/app_icon.png /tmp/yutaka-setup-payload/icon.png
NO_AT_BRIDGE=1 G_DEBUG=fatal-warnings xvfb-run -a \
  /tmp/yutaka-setup /tmp/yutaka-setup-payload --check-ui
```

For the UI check, the payload folder should contain `icon.png`; CI prepares this
folder. No installation occurs during `--check-ui`.
