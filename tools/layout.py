"""Print a compact UI tree from a `uitest dumpLayout` JSON file.

Usage: python3 tools/layout.py /tmp/layout.json [--all]

Bounds are printed in vp (image pixels / density, default 3.5).
Only nodes with text, ids, or explicit sizes are shown unless --all is passed.
"""
import json
import sys

DENSITY = 3.5


def px(value):
    return round(value / DENSITY, 1)


def parse_bounds(text):
    try:
        left, rest = text.split('][')
        x1, y1 = left.strip('[').split(',')
        x2, y2 = rest.strip(']').split(',')
        return (int(x1), int(y1), int(x2), int(y2))
    except Exception:
        return (0, 0, 0, 0)


def walk(node, depth, show_all, out):
    attributes = node.get('attributes', {})
    children = node.get('children', []) or []
    text = attributes.get('text', '')
    node_id = attributes.get('id', '')
    node_type = attributes.get('type', '')
    bounds = parse_bounds(attributes.get('bounds', '[0,0][0,0]'))
    x1, y1, x2, y2 = bounds
    width = x2 - x1
    height = y2 - y1
    interesting = bool(text) or bool(node_id) or node_type in (
        'Button', 'TextInput', 'TextArea', 'Slider', 'Scroll', 'Image')
    if show_all or interesting:
        label = text.replace('\n', '\\n')
        line = (f'{"  " * depth}[{px(x1)},{px(y1)} {px(width)}x{px(height)}]'
                f' {node_type}')
        if label:
            line += f' "{label}"'
        if node_id:
            line += f' #{node_id}'
        out.append(line)
        depth += 1
    for child in children:
        walk(child, depth, show_all, out)


def main():
    path = sys.argv[1]
    show_all = '--all' in sys.argv
    with open(path, 'r', encoding='utf-8') as handle:
        root = json.load(handle)
    out = []
    walk(root, 0, show_all, out)
    print(f'{len(out)} nodes')
    print('\n'.join(out))


if __name__ == '__main__':
    main()
