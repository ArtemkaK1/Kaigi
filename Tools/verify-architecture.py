#!/usr/bin/env python3
"""Repository-local MVVM and design-token guard. No third-party dependencies."""
from pathlib import Path
import re, sys
root = Path(__file__).resolve().parents[1] / 'Kaigi'
violations = []
if not root.is_dir():
    sys.exit('FAIL: Kaigi source root is missing')
for path in root.rglob('*.swift'):
    text = path.read_text()
    code = re.sub(r'//[^\n]*', '', text)
    relative = path.relative_to(root)
    imports = re.findall(r'^import (\w+)', code, re.M)
    if relative.parts[0] == 'Domain':
        for module in imports:
            if module != 'Foundation': violations.append(f'{relative}: domain imports {module}')
    if relative.parts[0] == 'Features':
        if path.name.endswith('ViewModel.swift'):
            for module in imports:
                if module not in ('Foundation', 'Observation'): violations.append(f'{relative}: view model imports {module}')
        for forbidden in ('NoteRepository', 'MeetingNote', 'ModelContext', 'ModelContainer', 'EKEventStore', 'NSWorkspace', 'NSSavePanel', 'UserDefaults', 'LanguageModelSession', 'SystemPreferencesService'):
            if re.search(r'\b' + forbidden + r'\b', code): violations.append(f'{relative}: infrastructure leak {forbidden}')
        if path.name.endswith('View.swift'):
            for match in re.finditer(r'\.(?:font|fontWeight)\s*\(|\bColor\s*\(|\.foregroundStyle\(\.(?:primary|secondary|red|orange)', code):
                violations.append(f'{relative}: authored font/color bypass at offset {match.start()}')
            if re.search(r'\btry\b|\bNotesStore\b|\bCalendarProvider\b', code): violations.append(f'{relative}: view contains data/business access')
    if relative.parts[0] in ('Features','DesignSystem','App'):
        if re.search(r'\bspacing:\s*\d|\.padding\(\s*(?:\.[a-zA-Z]+,\s*)?\d|\.padding\(\)', code):
            violations.append(f'{relative}: non-token authored spacing')
if violations:
    print('\n'.join(violations)); sys.exit(1)
print('PASS: domain isolation, feature MVVM boundaries, semantic fonts/colors, and 8-point spacing')
