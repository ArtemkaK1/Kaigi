#!/usr/bin/env python3
"""Check (or --fix) blank lines before Swift functions, initializers and deinitializers.

Intentionally narrow: no layout, indentation, modifier or expression formatting.
Documentation and standalone declaration attributes stay attached.
"""
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
DECLARATION = re.compile(r'^\s*(?:(?:@\w+(?:\([^\n]*?\))?|(?:private|fileprivate|internal|public|open|static|class|final|override|required|convenience|mutating|nonmutating|nonisolated)(?:\([^)]*\))?)\s+)*(?:func\s|init[?!]?\s*\(|deinit\b)')
ATTRIBUTE = re.compile(r'^\s*@\w+(?:\([^\n]*\))?\s*$')


def separation_points(lines):
    points = set()
    for index, line in enumerate(lines):
        if not DECLARATION.match(line):
            continue
        start = index
        while start > 0:
            previous = lines[start - 1].strip()
            if previous.startswith('///') or ATTRIBUTE.match(lines[start - 1]):
                start -= 1
            elif previous.endswith('*/'):
                comment = start - 1
                while comment > 0 and '/*' not in lines[comment]:
                    comment -= 1
                if lines[comment].lstrip().startswith('/**'):
                    start = comment
                else:
                    break
            else:
                break
        previous = lines[start - 1].strip() if start else ''
        # Opening braces and conditional-compilation boundaries need no extra gap.
        if previous and not previous.endswith('{') and not previous.startswith('#'):
            points.add(start)
    return points


def main():
    fix = '--fix' in sys.argv
    failures = []
    paths = sorted(path for folder in ('Kaigi', 'KaigiTests', 'KaigiUITests', 'Tools')
                   for path in (ROOT / folder).rglob('*.swift'))
    for path in paths:
        lines = path.read_text().splitlines(keepends=True)
        points = separation_points(lines)
        if points and fix:
            path.write_text(''.join(('\n' if index in points else '') + line for index, line in enumerate(lines)))
        else:
            failures.extend(f'{path.relative_to(ROOT)}:{index + 1}: missing declaration separator' for index in sorted(points))
    if failures:
        sys.exit('\n'.join(failures))
    print(f'PASS: Swift declaration spacing ({len(paths)} files)')


if __name__ == '__main__':
    main()
