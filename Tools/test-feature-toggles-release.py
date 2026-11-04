#!/usr/bin/env python3
"""Compile the actual launch selector without DEBUG and reject QA overrides."""
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix="kaigi-release-toggles-") as folder:
    temporary = Path(folder)
    main = temporary / "main.swift"
    main.write_text('''
let arguments: [[String]] = [[], ["--all-features"], ["--sample"],
    ["--sample", "--all-features", "--context-history", "--mock-ai"],
    ["--marketing-fixtures"], ["--sample", "--marketing-fixtures"],
    ["--sample", "--marketing-fixtures", "--all-features"]]
for value in arguments {
    precondition(FeatureToggles.forLaunch(arguments: value) == .appStoreFree)
}
print("PASS: Release launch selection ignores all Debug availability overrides")
''')
    binary = temporary / "probe"
    subprocess.run(["xcrun", "swiftc", "-O", "-module-cache-path", str(temporary / "modules"),
        str(root / "Kaigi/Domain/Models/FeatureToggles.swift"),
        str(root / "Kaigi/App/FeatureToggles+Launch.swift"), str(main), "-o", str(binary)], check=True)
    subprocess.run([str(binary)], check=True)
