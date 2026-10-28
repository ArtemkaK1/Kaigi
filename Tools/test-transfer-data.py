#!/usr/bin/env python3
"""Synthetic transfer regression checks; never reads a user's containers."""
import importlib.util
from pathlib import Path
import plistlib
import sqlite3
import tempfile
import unittest
spec = importlib.util.spec_from_file_location('transfer', Path(__file__).with_name('transfer-data.py'))
transfer = importlib.util.module_from_spec(spec); spec.loader.exec_module(transfer)

class TransferTests(unittest.TestCase):
    def test_wal_preferences_and_no_overwrite(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder); old = root / 'old'; new = root / 'new'; new.mkdir()
            store = old / 'Library/Application Support/default.store'; store.parent.mkdir(parents=True)
            prefs = old / f'Library/Preferences/{transfer.OLD_ID}.plist'; prefs.parent.mkdir(parents=True)
            expected = {'selectedCalendars': [], 'calendarOnboarding.v1': b'synthetic', 'aiEnabled': False, 'remindersEnabled': True}
            prefs.write_bytes(plistlib.dumps(expected | {'unrelated': 'excluded'}))
            with sqlite3.connect(store) as db:
                db.execute('PRAGMA journal_mode=WAL')
                for table in ('ZMEETINGSERIES', 'ZMEETINGNOTE', 'ZNOTEREVISION'):
                    db.execute(f'CREATE TABLE {table}(id TEXT, content TEXT)')
                    db.execute(f'INSERT INTO {table} VALUES (?, ?)', ('stable-id', 'Synthetic private context'))
                db.commit()
                original = store.read_bytes()
                transfer.export_data(old, root / 'backup')
                self.assertEqual(store.read_bytes(), original)
            transfer.import_data(root / 'backup', new)
            self.assertEqual(plistlib.loads((new / f'Library/Preferences/{transfer.NEW_ID}.plist').read_bytes()), expected)
            with sqlite3.connect(new / 'Library/Application Support/default.store') as db:
                self.assertEqual(db.execute('SELECT * FROM ZMEETINGNOTE').fetchone(), ('stable-id', 'Synthetic private context'))
            with self.assertRaises(FileExistsError): transfer.import_data(root / 'backup', new)
            with self.assertRaises(FileExistsError): transfer.export_data(old, root / 'backup')
            self.assertEqual(store.read_bytes(), original)
    def test_corrupt_backup_never_writes_destination(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder); backup = root / 'backup'; backup.mkdir(); destination = root / 'new'; destination.mkdir()
            (backup / 'manifest.json').write_text('{}')
            with self.assertRaises(ValueError): transfer.import_data(backup, destination)
            self.assertEqual(list(destination.iterdir()), [])

unittest.main()
