"""Coarse visual dump of a phone screenshot for layout sanity checks.

Usage: python3 tools/preview.py shot.jpeg [--cols 46]

Prints a character map (one char per cell) plus detected horizontal colour bands.
Characters: ' ' paper/white, '.' off-white, ':' light grey, '#' dark ink,
'B' blue, 'Y' beige, 'w' white-ish on dark, '-' near black, '?' other.
"""
import sys
from collections import Counter

from PIL import Image

PALETTE = [
    ((246, 246, 242), ' '),
    ((255, 255, 255), ' '),
    ((251, 251, 248), '.'),
    ((242, 243, 238), '.'),
    ((236, 238, 232), ':'),
    ((234, 231, 223), 'Y'),
    ((16, 17, 14), '#'),
    ((25, 26, 24), '-'),
    ((23, 24, 26), '-'),
    ((36, 91, 255), 'B'),
    ((119, 121, 112), 'g'),
    ((154, 156, 149), 'g'),
    ((215, 216, 209), ':'),
    ((237, 240, 255), 'b'),
]


def classify(rgb):
    best = None
    best_d = 1 << 30
    for color, ch in PALETTE:
        d = sum((rgb[i] - color[i]) ** 2 for i in range(3))
        if d < best_d:
            best_d = d
            best = ch
    return best


def main():
    path = sys.argv[1]
    cols = 46
    if '--cols' in sys.argv:
        cols = int(sys.argv[sys.argv.index('--cols') + 1])
    im = Image.open(path).convert('RGB')
    w, h = im.size
    rows = max(1, int(cols * h / w / 2.1))
    cell_w = w / cols
    cell_h = h / rows

    print(f'image {w}x{h} cols={cols} rows={rows}')
    lines = []
    for ry in range(rows):
        line = []
        for rx in range(cols):
            box = (int(rx * cell_w), int(ry * cell_h),
                   max(int(rx * cell_w) + 1, int((rx + 1) * cell_w)),
                   max(int(ry * cell_h) + 1, int((ry + 1) * cell_h)))
            crop = im.crop(box).resize((1, 1), Image.BOX)
            line.append(classify(crop.getpixel((0, 0))))
        lines.append(''.join(line))
    for i, line in enumerate(lines):
        print(f'{int(i * cell_h):>4} |{line}|')

    # Horizontal colour bands from row means.
    print('\nrow bands (start-end px, mean rgb):')
    band_start = 0
    prev = None
    for y in range(h):
        row = im.crop((0, y, w, y + 1)).resize((1, 1), Image.BOX)
        rgb = row.getpixel((0, 0))
        key = tuple(v // 12 for v in rgb)
        if prev is None or key != prev:
            if prev is not None and y - band_start >= 6:
                mean = im.crop((0, band_start, w, y)).resize((1, 1), Image.BOX).getpixel((0, 0))
                print(f'  {band_start:>4}-{y:<4} {y - band_start:>4}px rgb{mean}')
            band_start = y
            prev = key
    mean = im.crop((0, band_start, w, h)).resize((1, 1), Image.BOX).getpixel((0, 0))
    print(f'  {band_start:>4}-{h:<4} {h - band_start:>4}px rgb{mean}')


if __name__ == '__main__':
    main()
