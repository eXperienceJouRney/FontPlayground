"""Render a screenshot region as high-resolution ASCII luminance art.

Usage: python3 tools/ascii.py shot.jpeg x y w h [cols]
Coordinates are in image pixels. Character ramp: ' .:-=+*#%@' (dark -> bright)
"""
import sys

from PIL import Image, ImageOps

RAMP = ' .:-=+*#%@'


def main():
    path = sys.argv[1]
    x, y, w, h = (int(v) for v in sys.argv[2:6])
    cols = int(sys.argv[6]) if len(sys.argv) > 6 else 90
    im = Image.open(path).convert('L').crop((x, y, x + w, y + h))
    rows = max(1, int(cols * h / w / 2.1))
    im = im.resize((cols, rows), Image.LANCZOS)
    im = ImageOps.autocontrast(im, cutoff=1)
    print(f'crop {x},{y} {w}x{h} -> {cols}x{rows}')
    pix = im.load()
    for ry in range(rows):
        line = []
        for rx in range(cols):
            value = pix[rx, ry]
            line.append(RAMP[min(len(RAMP) - 1, value * len(RAMP) // 256)])
        print(''.join(line))


if __name__ == '__main__':
    main()
