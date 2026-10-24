#!/bin/zsh
# Standalone QA app; excluded from every Xcode production target.
set -eu
qa_root="$(cd "$(dirname "$0")/.." && pwd)"
qa_bundle="/tmp/MeetrailCalendarQA.app"
mkdir -p "$qa_bundle/Contents/MacOS"
if [[ ! -x "$qa_bundle/Contents/MacOS/MeetrailCalendarQA" || "$qa_root/Tools/CalendarQA.swift" -nt "$qa_bundle/Contents/MacOS/MeetrailCalendarQA" ]]; then
cat > "$qa_bundle/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?><plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>MeetrailCalendarQA</string>
<key>CFBundleIdentifier</key><string>com.volrik.meetrail.calendarqa</string>
<key>CFBundleName</key><string>Meetrail Calendar QA</string>
<key>NSCalendarsFullAccessUsageDescription</key><string>Create only attendee-free Meetrail QA test fixtures in a dedicated calendar, and remove only fixtures tracked by this QA workflow.</string>
</dict></plist>
PLIST
xcrun swiftc "$qa_root/Tools/CalendarQA.swift" -o "$qa_bundle/Contents/MacOS/MeetrailCalendarQA"
codesign --force --sign - "$qa_bundle"
fi
open -n "$qa_bundle" --args "$@"
