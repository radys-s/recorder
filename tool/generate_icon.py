# -*- coding: utf-8 -*-
"""Generates every raster the app's identity needs, from one description.

The mark is a record ring with a three-bar waveform inside it, and the middle
bar is the recording red. The ring says "this records", the wave says "this is
audio", and the red says "it is running" — which is the whole product in one
glyph, and it survives being scaled down to 48 px, which a literal microphone
does not.

Run from the project root:

    python tool/generate_icon.py

Everything it writes is committed, so this only needs re-running when the mark
itself changes. Requires Pillow.
"""
import os
from PIL import Image, ImageDraw

S = 1024

# The theme's seed (#38547A) lightened and darkened a little, so the tile has
# depth without turning into a gradient that fights the mark.
SLATE_TOP = (62, 92, 134)
SLATE_BOTTOM = (42, 64, 96)

# Not pure white: it sits on a blue tile, and #FFFFFF vibrates against it.
INK = (238, 243, 250)

# The same red the recording state uses in the app.
RECORD = (224, 87, 92)

# Surfaces the launch window paints, sampled from the running app so the splash
# and the first frame are the same colour.
LAUNCH_LIGHT = '#F9F9FF'
LAUNCH_DARK = '#111318'

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def _gradient(size):
    img = Image.new('RGB', (size, size))
    draw = ImageDraw.Draw(img)
    for y in range(size):
        t = y / (size - 1)
        draw.line(
            [(0, y), (size, y)],
            fill=tuple(round(a + (b - a) * t)
                       for a, b in zip(SLATE_TOP, SLATE_BOTTOM)),
        )
    return img


def _mark(draw, size):
    """Ring plus waveform, centred on a `size` canvas."""
    centre = size / 2

    radius = 0.335 * size
    draw.ellipse(
        [centre - radius, centre - radius, centre + radius, centre + radius],
        outline=INK,
        width=int(0.058 * size),
    )

    heights = (0.46, 0.86, 0.46)
    colours = (INK, RECORD, INK)
    thickness = 0.080 * size
    gap = 0.060 * size
    span = 0.42 * size

    total = len(heights) * thickness + (len(heights) - 1) * gap
    x = centre - total / 2
    for height, colour in zip(heights, colours):
        bar = max(height * span, thickness)
        draw.rounded_rectangle(
            [x, centre - bar / 2, x + thickness, centre + bar / 2],
            radius=thickness / 2,
            fill=colour,
        )
        x += thickness + gap


def icon(size=S):
    img = _gradient(size)
    _mark(ImageDraw.Draw(img), size)
    return img


def foreground(size=S):
    """The mark alone, for Android's adaptive icon.

    A launcher masks the outer third of an adaptive icon away, and
    flutter_launcher_icons wraps this file in a further `android:inset="16%"`,
    leaving 68% of the canvas usable. Filling 82% of *this* image therefore puts
    the glyph at 56% of the finished 108dp icon — comfortably inside the 72dp
    circle a round mask leaves visible, without swimming in it.
    """
    glyph = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    _mark(ImageDraw.Draw(glyph), size)

    outer = 2 * (0.335 + 0.029)  # ring radius plus half its stroke
    inner = round(size * 0.82 / outer)
    glyph = glyph.resize((inner, inner), Image.LANCZOS)

    canvas = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    canvas.paste(glyph, ((size - inner) // 2, (size - inner) // 2), glyph)
    return canvas


def tile(size=S):
    """The icon with rounded corners, for the launch screens.

    The splash shows this floating on a plain surface, so it needs its own
    corners — it is not being masked by a launcher.
    """
    img = icon(size).convert('RGBA')
    mask = Image.new('L', (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, size - 1, size - 1], radius=int(0.22 * size), fill=255)
    img.putalpha(mask)
    return img


def _write(img, *parts):
    path = os.path.join(ROOT, *parts)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)
    print(os.path.join(*parts))


def main():
    _write(icon(), 'assets', 'icon', 'icon.png')
    _write(_gradient(S), 'assets', 'icon', 'icon_background.png')
    _write(foreground(), 'assets', 'icon', 'icon_foreground.png')
    _write(tile(), 'assets', 'icon', 'launch_tile.png')

    source = tile()

    # Android: one bucket per density, drawn at 96dp.
    android = {'mdpi': 96, 'hdpi': 144, 'xhdpi': 192,
               'xxhdpi': 288, 'xxxhdpi': 384}
    for bucket, px in android.items():
        _write(source.resize((px, px), Image.LANCZOS),
               'android', 'app', 'src', 'main', 'res',
               'drawable-' + bucket, 'launch_image.png')

    # iOS: the storyboard centres the image at its natural size, so 1x is the
    # point size and the suffixed files are the same glyph at 2x and 3x.
    for suffix, px in (('', 120), ('@2x', 240), ('@3x', 360)):
        _write(source.resize((px, px), Image.LANCZOS),
               'ios', 'Runner', 'Assets.xcassets', 'LaunchImage.imageset',
               'LaunchImage%s.png' % suffix)


if __name__ == '__main__':
    main()
