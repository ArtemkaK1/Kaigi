"""Fail closed before upload; never install the package or print private profile data."""

import base64
import os
from pathlib import Path
import plistlib
import re
import stat
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET


# Apple's SecPolicy.list: MacDistributionInstaller (105). This policy pins the
# Apple root, WWDR intermediate, and Mac Installer Distribution leaf marker OID.
MAC_DISTRIBUTION_INSTALLER_POLICY = "1.2.840.113635.100.1.105"


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


def verify_payload_permissions(app):
    """Installed files belong to root; other users must read and traverse the app."""
    for path in [app, *app.rglob("*")]:
        mode = path.lstat().st_mode
        # Symlink mode bits do not control access; check the actual payload targets.
        if stat.S_ISLNK(mode):
            continue
        required = stat.S_IROTH | stat.S_IXOTH if stat.S_ISDIR(mode) else stat.S_IROTH
        require(mode & required == required,
                f"Payload is not readable/traversable by installed users: "
                f"{app.name}/{path.relative_to(app)} (mode {stat.S_IMODE(mode):04o}); "
                "build and sign with umask 022 before exporting again")


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


def verify_package_signature(details, team, returncode=0):
    statuses = re.findall(r"^[ \t]*Status:[ \t]*([^\r\n]+)", details, re.MULTILINE)
    status = statuses[0].strip() if len(statuses) == 1 else "<missing or ambiguous>"
    # This summary classifies the certificate family, not just its distribution
    # purpose. Mac App Store installer certificates can be labelled (Development).
    # The leaf identity below AND the dedicated Apple trust policy remain required.
    trusted = {
        "signed by a developer certificate issued by Apple for distribution",
        "signed by a certificate trusted by macOS",
        "signed by a certificate trusted by Mac OS X",
        "signed by a developer certificate issued by Apple",
        "signed by a developer certificate issued by Apple (Development)",
    }
    require(returncode == 0 and status in trusted,
            f"Installer signature is not trusted (pkgutil exit {returncode}; status: {status})")
    leaves = re.findall(r"^[ \t]*1\.[ \t]+([^\r\n]+)", details, re.MULTILINE)
    leaf = leaves[0].strip() if len(leaves) == 1 else ""
    kinds = ("3rd Party Mac Developer Installer", "Mac Installer Distribution", "Developer ID Installer",
             "Apple Development", "Apple Distribution", "Mac Developer")
    kind = next((name for name in kinds if leaf.startswith(name + ":")), "unrecognized")
    leaf_team = re.search(r"\(([A-Z0-9]{10})\)$", leaf)
    observed_team = leaf_team[1] if leaf_team else "missing"
    require(kind in kinds[:2] and observed_team == team,
            "Installer lacks the team's Mac Installer Distribution leaf signature "
            f"(type: {kind}; team: {observed_team}; pkgutil status: {status})")
    return status


def installer_certificates(toc):
    """Read public signing certificates from the same XAR signature pkgutil checks."""
    root = ET.fromstring(toc)
    legacy = root.findall("./{*}toc/{*}signature")
    extended = root.findall("./{*}toc/{*}x-signature")
    layout = f"signature={len(legacy)}; x-signature={len(extended)}"
    require(bool(legacy or extended) and len(legacy) <= 1 and len(extended) <= 1,
            f"Missing or ambiguous installer XAR signatures ({layout})")
    chains = []
    # Only public X.509 data is encoded in the XAR table of contents. The App Store
    # Connect private .p8 secret remains raw and never enters this parsing path.
    for signature in legacy + extended:
        nodes = signature.findall("./{*}KeyInfo/{*}X509Data/{*}X509Certificate")
        require(1 <= len(nodes) <= 8,
                f"Installer signature has a missing or unexpected certificate chain ({layout}; certificates={len(nodes)})")
        chain = [base64.b64decode("".join((node.text or "").split()), validate=True) for node in nodes]
        require(all(chain), f"Installer signature contains an empty certificate ({layout})")
        chains.append(chain)
    # RSA + CMS packages are valid, but do not silently validate one signer while
    # pkgutil reports another. Both representations must carry the same chain.
    require(all(chain == chains[0] for chain in chains),
            f"Installer XAR signatures contain conflicting certificate chains ({layout})")
    return chains[0]


def verify_installer_certificate_chain(package):
    toc = run("/usr/bin/xar", "--dump-toc=-", "-f", str(package)).stdout
    certificates = installer_certificates(toc)
    with tempfile.TemporaryDirectory(prefix="meetrail-installer-trust-") as temporary:
        command = ["/usr/bin/security", "verify-cert", "-N", "-p", MAC_DISTRIBUTION_INSTALLER_POLICY]
        for index, data in enumerate(certificates):
            path = Path(temporary) / f"certificate-{index}.cer"
            path.write_bytes(data)
            command.extend(["-c", str(path)])
        # Embedded certificates are supplied as an untrusted chain (-c), never as
        # trust anchors (-r). macOS must validate against its own Apple anchors.
        result = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
        diagnostic = (result.stdout + result.stderr).decode(errors="replace")
        codes = sorted(set(re.findall(r"\b(?:CSSMERR_[A-Z0-9_]+|errSec[A-Za-z0-9]+)\b", diagnostic)))
        reason = ", ".join(codes) if codes else "no symbolic error code reported"
        require(result.returncode == 0,
                f"Mac Installer Distribution Apple trust policy failed (security exit {result.returncode}; {reason})")


def main():
    require(len(sys.argv) == 5, "Usage: verify_distribution.py archive|package PATH VERSION BUILD")
    mode, path, version, number = sys.argv[1:]
    identifier = os.environ.get("APP_IDENTIFIER", "com.volrik.meetrail")
    team = os.environ.get("APPLE_TEAM_ID", "WX557M9HD2")
    require(identifier == "com.volrik.meetrail" and team == "WX557M9HD2", "Unexpected distribution identity")
    if mode == "archive":
        verify_app(Path(path) / "Products/Applications/Meetrail.app", identifier, team, version, number, False)
    elif mode == "package":
        signature = subprocess.run(["/usr/sbin/pkgutil", "--check-signature", path],
                                   stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
        status = verify_package_signature(signature.stdout.decode(errors="replace"), team, signature.returncode)
        print(f"Installer signature status: {status}")
        verify_installer_certificate_chain(path)
        print(f"Installer certificate: Mac Installer Distribution; team {team}; Apple trust policy verified")
        with tempfile.TemporaryDirectory(prefix="meetrail-package-") as temporary:
            expanded = Path(temporary) / "expanded"
            run("/usr/sbin/pkgutil", "--expand-full", path, str(expanded))
            apps = list(expanded.rglob("*.app"))
            require(len(apps) == 1 and apps[0].name == "Meetrail.app", "Unexpected application payload")
            verify_payload_permissions(apps[0])
            verify_app(apps[0], identifier, team, version, number, True)
    else:
        raise ValueError("Unknown verification mode")
    print(f"Verified {mode}: {identifier} {version} ({number})")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, plistlib.InvalidFileException, ET.ParseError) as error:
        sys.exit(f"Distribution verification failed: {error}")
