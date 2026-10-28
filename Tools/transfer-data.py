#!/usr/bin/env python3
"""Owner-run, offline transfer. Never accesses an inferred container or overwrites files.
Quit both apps first. See Docs/DataMigration.md. Backups contain private notes.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import plistlib
import shutil
import sqlite3
import subprocess
import tempfile

KEYS = ('selectedCalendars', 'calendarOnboarding.v1', 'aiEnabled', 'remindersEnabled')
OLD_ID = 'com.volrik.meetrail.app'
NEW_ID = 'com.volrik.kaigi'

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def check_store(path):
    with sqlite3.connect(path.as_uri() + '?mode=ro', uri=True) as db:
        if db.execute('PRAGMA integrity_check').fetchone()[0] != 'ok':
            raise ValueError('Store integrity check failed; retain the original and stop.')
        tables = {row[0].upper() for row in db.execute("SELECT name FROM sqlite_master WHERE type='table'")}
        if not {'ZMEETINGSERIES', 'ZMEETINGNOTE', 'ZNOTEREVISION'} <= tables:
            raise ValueError('Not a compatible meeting-note store.')
        return {table: db.execute('SELECT count(*) FROM ' + table).fetchone()[0]
                for table in ('ZMEETINGSERIES', 'ZMEETINGNOTE', 'ZNOTEREVISION')}

def export_data(source, output):
    source, output = source.resolve(), output.resolve()
    if output.exists(): raise FileExistsError('Backup destination must not exist.')
    if source == output or source in output.parents:
        raise ValueError('Save the backup outside the source container.')
    store = source / 'Library/Application Support/default.store'
    if not store.is_file(): raise FileNotFoundError('Choose the old app container Data folder containing default.store.')
    output.parent.mkdir(parents=True, exist_ok=True)
    # Snapshot all sidecars together, then consolidate only the disposable copy.
    with tempfile.TemporaryDirectory(dir=output.parent) as work:
        work = Path(work)
        for item in store.parent.glob('default.store*'):
            if item.is_symlink() or not item.is_file(): raise ValueError('Unexpected store component.')
            shutil.copy2(item, work / item.name)
        counts = check_store(work / 'default.store')
        package = work / 'package'; package.mkdir(mode=0o700)
        with sqlite3.connect(work / 'default.store') as db, sqlite3.connect(package / 'default.store') as target:
            db.backup(target)
        if check_store(package / 'default.store') != counts: raise ValueError('Backup verification failed.')
        prefs_path = source / f'Library/Preferences/{OLD_ID}.plist'
        prefs = plistlib.loads(prefs_path.read_bytes()) if prefs_path.exists() else {}
        (package / 'preferences.plist').write_bytes(plistlib.dumps({key: prefs[key] for key in KEYS if key in prefs}))
        for file in package.iterdir(): file.chmod(0o600)
        manifest = {'format': 1, 'source_bundle': OLD_ID, 'destination_bundle': NEW_ID,
                    'swift_module': 'Meetrail', 'counts': counts,
                    'sha256': {name: digest(package / name) for name in ('default.store', 'preferences.plist')}}
        (package / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
        (package / 'manifest.json').chmod(0o600)
        # Atomic publication within the same filesystem; no existing backup is replaced.
        package.rename(output)
    return counts

def import_data(backup, destination):
    backup, destination = backup.resolve(), destination.resolve()
    manifest = json.loads((backup / 'manifest.json').read_text())
    if (manifest.get('format'), manifest.get('source_bundle'), manifest.get('destination_bundle'), manifest.get('swift_module')) != (1, OLD_ID, NEW_ID, 'Meetrail'):
        raise ValueError('Unsupported backup identity or version.')
    for name in ('default.store', 'preferences.plist'):
        if (backup / name).is_symlink() or digest(backup / name) != manifest['sha256'][name]:
            raise ValueError('Backup checksum mismatch; nothing imported.')
    if check_store(backup / 'default.store') != manifest['counts']: raise ValueError('Backup count mismatch.')
    prefs = plistlib.loads((backup / 'preferences.plist').read_bytes())
    if set(prefs) - set(KEYS): raise ValueError('Unexpected preference keys.')
    # Only write to an owner-selected existing Data folder; never infer/access a sandbox.
    if not destination.is_dir(): raise ValueError('Choose the new app container Data folder after first launch and quit.')
    support = destination / 'Library/Application Support'
    prefdir = destination / 'Library/Preferences'
    pref = prefdir / f'{NEW_ID}.plist'
    if any(support.glob('default.store*')) or pref.exists():
        raise FileExistsError('Destination already has a store or preferences. Move them to a separate rollback folder first; never overwrite.')
    support.mkdir(parents=True, exist_ok=True); prefdir.mkdir(parents=True, exist_ok=True)
    created = []
    try:
        for source, target in [(backup / 'default.store', support / 'default.store'), (backup / 'preferences.plist', pref)]:
            with source.open('rb') as reader, target.open('xb') as writer:
                created.append(target); os.chmod(target, 0o600); shutil.copyfileobj(reader, writer)
        if check_store(support / 'default.store') != manifest['counts']: raise ValueError('Imported store verification failed.')
    except Exception:
        # Roll back only files created by this exact invocation; originals are never touched.
        for target in created: target.unlink()
        raise
    return manifest['counts']

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apps-are-closed', action='store_true', required=True)
    commands = parser.add_subparsers(dest='command', required=True)
    export = commands.add_parser('export'); export.add_argument('--source-data', type=Path, required=True); export.add_argument('--output', type=Path, required=True)
    restore = commands.add_parser('import'); restore.add_argument('--backup', type=Path, required=True); restore.add_argument('--destination-data', type=Path, required=True)
    args = parser.parse_args()
    for app in ('Meetrail', 'Kaigi'):
        if subprocess.run(['pgrep', '-x', app], stdout=subprocess.DEVNULL).returncode == 0:
            parser.error('Quit both Meetrail and Kaigi, including synthetic QA instances, before transferring.')
    counts = export_data(args.source_data, args.output) if args.command == 'export' else import_data(args.backup, args.destination_data)
    print('Verified transfer:', counts)
    print('Keep the backup and old installation. Grant calendar/notification access and enable login separately in Kaigi.')

if __name__ == '__main__': main()
