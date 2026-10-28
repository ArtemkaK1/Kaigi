# Meetrail → Kaigi: owner-mediated data transfer

Kaigi has a new application identity. No transfer runs automatically, and no app code tries to escape its sandbox. Keep the old application installed until you have verified every important note in Kaigi. This procedure is local; do not commit or upload the backup.

## Identity inventory

| Item | Existing | Kaigi |
|---|---|---|
| Bundle / preferences domain | `com.volrik.meetrail.app` | `com.volrik.kaigi` |
| Sandbox data root | `~/Library/Containers/com.volrik.meetrail.app/Data` | `~/Library/Containers/com.volrik.kaigi/Data` |
| Store relative to data root | `Library/Application Support/default.store` | unchanged |
| Swift model module | `Meetrail` | **preserved** |
| Model entities | `MeetingSeries`, `MeetingNote`, `NoteRevision` | unchanged |
| CloudKit | `.none` | unchanged |
| Selection key | `selectedCalendars` | unchanged, including empty and temporarily missing IDs |
| Other preferences | `calendarOnboarding.v1`, `aiEnabled`, `remindersEnabled` | unchanged |

The old `com.volrik.meetrail` container also exists on the development Mac. It belongs to an earlier identity and is **not** an automatic fallback. This tool accepts only the documented `com.volrik.meetrail.app` source identity. If your notes live under a different identity, stop and have its configuration inspected rather than substituting paths blindly.

The app target and executable are Kaigi; `PRODUCT_MODULE_NAME = Meetrail` and `@testable import Meetrail` remain intentionally. Changing that runtime namespace would introduce an unnecessary schema compatibility risk. All model declarations, stored properties, UUIDs, system occurrence/series keys, and the default SwiftData configuration remain unchanged. No store is reset after an error.

## Before transfer

1. In the old app, finish editing, wait for “Saved locally,” and export important occurrence notes to Markdown as an additional human-readable backup. Markdown alone does not preserve UUIDs, all revisions, or series preferences.
2. Quit both apps normally, including QA copies, so drafts and SQLite transactions finish. Leave launch at login unchanged until you choose to switch applications.
3. Launch Kaigi once, then quit it normally. You do not need to connect a calendar or grant permissions to initialize its new container.
4. Use Finder → Go → Go to Folder to inspect the two data roots above. Container access is mediated by the owner and macOS; the new sandbox cannot read the old container. If macOS blocks access, grant the required folder access to the owner-run terminal/Finder when prompted, or stop. Do not disable SIP or alter container security.
5. If Kaigi already has meaningful notes, **do not use this whole-store restore**. It does not merge stores. Retain both and export/copy reviewed occurrence notes instead.

## Export a verified backup

Run from this checkout after quitting both apps. Pick a new private backup directory outside Git (the example does not already exist):

```sh
python3 Tools/transfer-data.py --apps-are-closed export \
  --source-data "$HOME/Library/Containers/com.volrik.meetrail.app/Data" \
  --output "$HOME/Desktop/Kaigi-private-backup-2026-10-28"
```

The helper copies the old store **and its sidecars** to temporary private storage, consolidates only that copy with SQLite's backup API, checks integrity and entity counts, and writes a checksum manifest plus the four supported preferences. It never opens the original database through SQLite or modifies the source preferences. Keep the generated directory intact. The app process check rejects a transfer while either app is running.

## Restore into the new container

1. Quit Kaigi. In Finder, move its newly created `default.store` and **every** `default.store-*` sidecar from its Application Support folder to a separate private rollback folder. Move `Library/Preferences/com.volrik.kaigi.plist` there too, if present. This is a reversible move of the **new** app's files; keep them until verification is complete. Never move or remove the old app's source files.
2. Run:

```sh
python3 Tools/transfer-data.py --apps-are-closed import \
  --backup "$HOME/Desktop/Kaigi-private-backup-2026-10-28" \
  --destination-data "$HOME/Library/Containers/com.volrik.kaigi/Data"
```

The importer verifies identity, checksums, integrity and counts before writing; it refuses an existing destination store or preference file. It copies to explicit owner-selected paths and never overwrites a database. If it fails, leave the backup and old application intact. Restart the Mac before launching Kaigi after a preference-file transfer so the system preferences daemon drops any cached new-app defaults; this avoids cached onboarding preferences replacing imported selections.
3. Launch Kaigi. Verify note text, confirmed context, revision history, per-series context settings and selected calendar IDs (including intentionally empty selections). Open a synthetic/test occurrence and confirm a new edit survives relaunch. Keep the old installation and both backup/rollback folders until satisfied.
4. If the app cannot open the transferred store, stop. It will show an error without replacing the store. Retain all files for diagnosis. Do not reset/delete the store to make startup succeed.

## New macOS identity requirements

- Calendar permission must be granted again by an explicit Connect action. System calendars remain read-only. Calendar account sync must already exist in macOS; direct OAuth/REST/CalDAV connections are not implemented.
- Notification consent is per app. Re-enable reminders deliberately in Kaigi Settings after checking imported preferences. Pending notifications in the old app are separate and are not transferred or canceled by Kaigi.
- Login registration is an OS registration, not a stored boolean. Enable Kaigi at login after placing the final app in its intended location; separately disable the old app only when you are ready. Kaigi never unregisters Meetrail.
- AI settings transfer; model availability still depends on the OS, hardware, language and Apple Intelligence readiness. No note content is sent to a server.
- Window placement, system permission records, login registration and other OS-owned state are not copied.

## Validation scope

`python3 Tools/test-transfer-data.py` exercises a synthetic WAL store, revision/series/note rows, empty selection, binary onboarding preference, disabled AI, retained reminder preference, backup immutability, refusal to overwrite, and corrupt-manifest rejection. A separate pre/post-rename SwiftData probe opens the same synthetic store with the original repository implementation and Kaigi's implementation under module `Meetrail`, comparing UUIDs, occurrence identity, confirmed context, revisions and per-series preference. See the rebranding validation report for results. These checks do not constitute a transfer of the owner's real notes; **no real store has been migrated**.
