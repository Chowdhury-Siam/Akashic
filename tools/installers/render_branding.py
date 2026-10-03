#!/usr/bin/env python3
"""Render installer artwork from Yutaka's real icon and theme (requires Pillow)."""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).with_name("assets")
BACKGROUND = "#0F1216"
SURFACE = "#13181D"
OUTLINE = "#272F35"
ACCENT = "#00BD91"
TEXT = "#F3F5F6"
MUTED = "#ADB5BB"


def font(size, bold=False):
    # Optional Inter paths allow brand typography when rendering on a design host.
    names = ("Inter-Bold.ttf", "DejaVuSans-Bold.ttf") if bold else ("Inter-Regular.ttf", "DejaVuSans.ttf")
    for name in names:
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            pass
    raise RuntimeError("Install Inter or DejaVu Sans to regenerate installer artwork.")


def centered(draw, text, y, width, size, color=TEXT, bold=False):
    face = font(size, bold)
    x = (width - draw.textlength(text, font=face)) / 2
    draw.text((x, y), text, font=face, fill=color)


def paste_icon(image, box):
    icon = Image.open(ROOT / "assets/icons/app_icon.png").convert("RGBA")
    icon.thumbnail((box[2], box[3]), Image.Resampling.LANCZOS)
    image.paste(icon, (box[0], box[1]), icon)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    sidebar = Image.new("RGB", (328, 628), BACKGROUND)
    draw = ImageDraw.Draw(sidebar)
    draw.rounded_rectangle((20, 20, 308, 608), radius=38, fill=SURFACE, outline=OUTLINE, width=2)
    paste_icon(sidebar, (70, 104, 188, 188))
    centered(draw, "Yutaka", 324, 328, 42, bold=True)
    centered(draw, "Your finances.", 402, 328, 21, MUTED)
    centered(draw, "Your control.", 434, 328, 21, MUTED)
    draw.rounded_rectangle((100, 508, 228, 515), radius=3, fill=ACCENT)
    sidebar.save(OUT / "windows-sidebar.bmp")

    small = Image.new("RGB", (110, 110), BACKGROUND)
    paste_icon(small, (0, 0, 110, 110))
    small.save(OUT / "windows-icon.bmp")

    # Finder places the actual .app and Applications icons over these empty wells.
    # Neutral label backplates keep native Finder names readable in light/dark mode.
    mac = Image.new("RGB", (720, 440), BACKGROUND)
    draw = ImageDraw.Draw(mac)
    paste_icon(mac, (34, 26, 66, 66))
    draw.text((114, 29), "Yutaka", font=font(30, True), fill=TEXT)
    draw.text((115, 70), "Your finances, in your control.", font=font(15), fill=MUTED)
    draw.line((34, 112, 686, 112), fill=OUTLINE, width=1)
    centered(draw, "Drag Yutaka to Applications", 138, 720, 24, bold=True)
    for x in (210, 510):
        draw.rounded_rectangle((x - 96, 190, x + 96, 344), radius=26, fill=SURFACE, outline=OUTLINE)
        draw.rounded_rectangle((x - 75, 311, x + 75, 340), radius=10, fill="#747474")
    draw.line((328, 246, 388, 246), fill=ACCENT, width=5)
    draw.line((374, 232, 388, 246, 374, 260), fill=ACCENT, width=5)
    centered(draw, "Then open Yutaka from Applications.", 382, 720, 16, MUTED)
    mac.save(OUT / "macos-background.png", optimize=True)
    print(f"Rendered installer artwork in {OUT}")


if __name__ == "__main__":
    main()
