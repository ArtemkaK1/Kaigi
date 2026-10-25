"""Fail closed before upload; never install the package or print private profile data."""

import os
from pathlib import Path
import plistlib
import re
import subprocess
import sys
import tempfile


def require(condition, message):
    if not condition:
        raise ValueError(message)


def run(*args):
    result = subprocess.run(args, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
    require(result.returncode == 0, f"{Path(args[0]).name} failed: {result.stderr.decode(errors='replace').strip()}")
    return result


def validate_info(info, identifier, version, number):
    for name, expected in {
        "CFBundleIdentifier": identifier,
        "CFBundleShortVersionString": version,
        "CFBundleVersion": number,
        "LSUIElement": True,
        "LSMinimumSystemVersion": "15.0",
        "LSApplicationCategoryType": "public.app-category.productivity",
    }.items():
        require(info.get(name) == expected, f"Unexpected {name}")
    require(bool(info.get("NSCalendarsFullAccessUsageDescription")), "Missing calendar usage description")


def validate_entitlements(entitlements, identifier, team):
    for name in (
        "com.apple.security.app-sandbox",
        "com.apple.security.personal-information.calendars",
        "com.apple.security.files.user-selected.read-write",
    ):
        require(entitlements.get(name) is True, f"Missing required entitlement: {name}")
    allowed = {
        "com.apple.security.app-sandbox", "com.apple.security.personal-information.calendars",
        "com.apple.security.files.user-selected.read-write", "com.apple.developer.team-identifier",
        "com.apple.application-identifier", "application-identifier",
    }
    # Explicit false is harmless; true development access is never accepted.
    for name in ("get-task-allow", "com.apple.security.get-task-allow"):
        require(entitlements.get(name, False) is False, "Development get-task-allow entitlement is enabled")
        allowed.add(name)
    require(not set(entitlements) - allowed, "Unexpected entitlements; review capabilities before publishing")
    if "com.apple.developer.team-identifier" in entitlements:
        require(entitlements["com.apple.developer.team-identifier"] == team, "Entitlement team mismatch")
    for name in ("com.apple.application-identifier", "application-identifier"):
        if name in entitlements:
            require(entitlements[name] == f"{team}.{identifier}", "Entitlement application ID mismatch")


def verify_app(app, identifier, team, version, number, distribution):
    with (app / "Contents/Info.plist").open("rb") as file:
        validate_info(plistlib.load(file), identifier, version, number)
    run("/usr/bin/codesign", "--verify", "--deep", "--strict", str(app))
    details = run("/usr/bin/codesign", "-d", "--verbose=4", str(app)).stderr.decode()
    require(f"TeamIdentifier={team}" in details.splitlines(), "Code signature team mismatch")
    require(re.search(r"flags=.*\bruntime\b", details), "Hardened Runtime flag missing")
    entitlements = plistlib.loads(run("/usr/bin/codesign", "-d", "--entitlements", ":-", str(app)).stdout)
    validate_entitlements(entitlements, identifier, team)
    if distribution:
        require(re.search(r"^Authority=(Apple Distribution|3rd Party Mac Developer Application|Mac App Distribution):",
                          details, re.MULTILINE), "App lacks a Mac App Store distribution signature")
    profile = app / "Contents/embedded.provisionprofile"
    if profile.exists():
        data = plistlib.loads(run("/usr/bin/security", "cms", "-D", "-i", str(profile)).stdout)
        require(data.get("TeamIdentifier") == [team], "Provisioning profile team mismatch")
        if distribution:
            require(not data.get("ProvisionedDevices") and not data.get("ProvisionsAllDevices"),
                    "Development or non-store provisioning profile")
            require(data.get("Entitlements", {}).get("get-task-allow", False) is False,
                    "Development provisioning profile")


def verify_package_signature(details, team):
    require("Status: signed by a certificate trusted by" in details, "Installer signature is not trusted")
    require(re.search(r"(?:3rd Party Mac Developer Installer|Mac Installer Distribution):[^\n]*\(" +
                      re.escape(team) + r"\)", details), "Installer lacks the team's Mac Installer Distribution signature")


def main():
    require(len(sys.argv) == 5, "Usage: verify_distribution.py archive|package PATH VERSION BUILD")
    mode, path, version, number = sys.argv[1:]
    identifier = os.environ.get("APP_IDENTIFIER", "com.volrik.meetrail")
    team = os.environ.get("APPLE_TEAM_ID", "WX557M9HD2")
    require(identifier == "com.volrik.meetrail" and team == "WX557M9HD2", "Unexpected distribution identity")
    if mode == "archive":
        verify_app(Path(path) / "Products/Applications/Meetrail.app", identifier, team, version, number, False)
    elif mode == "package":
        signature = run("/usr/sbin/pkgutil", "--check-signature", path).stdout.decode()
        verify_package_signature(signature, team)
        with tempfile.TemporaryDirectory(prefix="meetrail-package-") as temporary:
            expanded = Path(temporary) / "expanded"
            run("/usr/sbin/pkgutil", "--expand-full", path, str(expanded))
            apps = list(expanded.rglob("*.app"))
            require(len(apps) == 1 and apps[0].name == "Meetrail.app", "Unexpected application payload")
            verify_app(apps[0], identifier, team, version, number, True)
    else:
        raise ValueError("Unknown verification mode")
    print(f"Verified {mode}: {identifier} {version} ({number})")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, plistlib.InvalidFileException) as error:
        sys.exit(f"Distribution verification failed: {error}")
