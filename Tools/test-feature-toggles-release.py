#!/usr/bin/env python3
"""Compile the actual launch policy without DEBUG and reject QA entitlement overrides."""
import os
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix="kaigi-release-toggles-") as folder:
    temporary = Path(folder)
    main = temporary / "main.swift"
    main.write_text('''
MainActor.assumeIsolated {
    let arguments: [[String]] = [[], ["--all-features"], ["--sample"], ["--simulate-entitlement"],
        ["--sample", "--all-features", "--context-history", "--mock-ai"],
        ["--sample", "--simulate-entitlement", "--saved-note-fixture"], ["--sample", "--all-features", "--simulate-entitlement"],
        ["--marketing-fixtures"], ["--sample", "--marketing-fixtures"],
        ["--sample", "--marketing-fixtures", "--all-features", "--simulate-entitlement"]]
    for value in arguments {
        let toggles = FeatureToggles.forLaunch(arguments: value)
        let store = EntitlementStore(provider: EntitlementLaunchPolicy.makeProvider(arguments: value))
        let access = FeatureAccess(toggles: toggles, entitlement: store)
        precondition(toggles == .released && store.state == .free)
        for feature in [AppFeature.meetingHistory, .recurringContext, .floatingNotes, .aiCleanUp, .aiStructure] {
            precondition(access.status(of: feature) == .requiresPro)
        }
        precondition(access.allows(.revisionHistoryUI))
        let presentation = ProPresentationPolicy.forLaunch(arguments: value)
        precondition(presentation.canPresent(from: .settings, access: access))
        for entry in [ProEntryPoint.meetingContext, .floatingNotes, .ai(.cleanUp), .ai(.structure)] {
            precondition(!presentation.canPresent(from: entry, access: access))
        }
    }
    print("PASS: Release resolves Free, shows Pro information in Settings, and ignores contextual QA overrides")
}
''')
    binary = temporary / "probe"
    subprocess.run(["xcrun", "swiftc", "-O", "-module-cache-path", str(temporary / "modules"),
        str(root / "Kaigi/Domain/Models/FeatureToggles.swift"),
        str(root / "Kaigi/Domain/Models/FeatureAccess.swift"),
        str(root / "Kaigi/Domain/Models/ProEntryPoint.swift"),
        str(root / "Kaigi/Domain/Protocols/AIRefinementService.swift"),
        str(root / "Kaigi/App/EntitlementStore.swift"),
        str(root / "Kaigi/App/FeatureToggles+Launch.swift"), str(main), "-o", str(binary)], check=True)
    subprocess.run([str(binary)], env={**os.environ, "KAIGI_PRO": "1", "KAIGI_ENTITLEMENT": "pro"}, check=True)
