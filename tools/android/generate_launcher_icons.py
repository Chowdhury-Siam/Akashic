#!/usr/bin/env python3
"""Render the existing Yutaka vector mark as mask-safe Android launcher and splash icons.

Requires Inkscape and Pillow. Keeps the square badge out of the adaptive
foreground: Android owns the icon shape and supplies the dark background.
"""
from pathlib import Path
import subprocess
import tempfile
import xml.etree.ElementTree as ET
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
SVG = '{http://www.w3.org/2000/svg}'
ET.register_namespace('', 'http://www.w3.org/2000/svg')
source = ET.parse(ROOT / 'assets/icons/yutaka_logo.svg').getroot()
foreground = ET.Element(SVG + 'svg', {
    'width': '1024', 'height': '1024', 'viewBox': '0 0 1024 1024',
})
foreground.append(source.find(SVG + 'defs'))
mark = source.find(SVG + 'g')
# The original badge clip and shadow belong to the full artwork, not the mark.
mark.attrib.pop('clip-path', None)
mark.attrib.pop('filter', None)
# 75% artwork scaling matches the existing mark size; compensate its 10px
# vertical offset so the mark itself is centered, rather than the old badge.
mark.set('transform', 'translate(128 120.5) scale(0.75)')
foreground.append(mark)
foreground_path = ROOT / 'assets/icons/yutaka_launcher_foreground.svg'
ET.ElementTree(foreground).write(foreground_path, encoding='utf-8', xml_declaration=True)

with tempfile.TemporaryDirectory() as directory:
    rendered = Path(directory) / 'foreground.png'
    subprocess.run([
        'inkscape', str(foreground_path), '--export-type=png',
        '--export-width=864', '--export-height=864',
        '--export-filename=' + str(rendered),
    ], check=True, capture_output=True)
    art = Image.open(rendered).convert('RGBA')
    # Android 12 masks splash icons to a circle two-thirds of the canvas.
    # Use the padded mark only; a badge/background here gets clipped by that mask.
    # 864px is the 288dp no-background splash canvas at 3x density.
    art.save(ROOT / 'android/app/src/main/res/drawable-nodpi/yutaka_splash_icon.png')
    # The launcher masks the central 72dp of the adaptive icon's 108dp canvas.
    legacy = art.crop((144, 144, 720, 720))
    background = Image.new('RGBA', legacy.size, '#001713')
    background.alpha_composite(legacy)
    round_mask = Image.new('L', legacy.size)
    ImageDraw.Draw(round_mask).ellipse((0, 0, 575, 575), fill=255)
    round_icon = background.copy()
    round_icon.putalpha(round_mask)
    for density, size in [('mdpi', 48), ('hdpi', 72), ('xhdpi', 96),
                          ('xxhdpi', 144), ('xxxhdpi', 192)]:
        target = ROOT / 'android/app/src/main/res' / ('mipmap-' + density)
        for name, image, output_size in [
            ('ic_launcher_foreground', art, size * 9 // 4),
            ('ic_launcher', background, size),
            ('ic_launcher_round', round_icon, size),
        ]:
            image.resize((output_size, output_size), Image.Resampling.LANCZOS).save(
                target / (name + '.webp'), lossless=True,
            )
