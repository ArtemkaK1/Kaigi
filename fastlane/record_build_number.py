"""Edit only Meetrail's app build settings after a confirmed upload; no Git/network side effects."""

from pathlib import Path
import re
import sys


APP_CONFIG = re.compile(
    r'(?P<indent>^[\t ]+)[A-F0-9]{24} /\* (?P<name>Debug|Release) configuration for PBXNativeTarget "Meetrail" \*/ = \{\n'
    r'(?P<body>.*?)^(?P=indent)\};', re.MULTILINE | re.DOTALL
)
BUILD = re.compile(r"^([\t ]*CURRENT_PROJECT_VERSION = )([0-9]+)(;[\t ]*)$", re.MULTILINE)
VERSION = re.compile(r"^[\t ]*MARKETING_VERSION = ([0-9.]+);[\t ]*$", re.MULTILINE)


def updated_project(source, number, version):
    if not re.fullmatch(r"[1-9][0-9]{0,17}", number):
        raise ValueError("Expected a positive integer build number of at most 18 digits")
    if not re.fullmatch(r"[0-9]+(?:\.[0-9]+){1,2}", version):
        raise ValueError("Invalid uploaded marketing version")
    configurations = list(APP_CONFIG.finditer(source))
    if len(configurations) != 2 or {match["name"] for match in configurations} != {"Debug", "Release"}:
        raise ValueError("Expected exactly the Meetrail app Debug and Release configurations")
    current = []
    for match in configurations:
        numbers = list(BUILD.finditer(match["body"]))
        if len(numbers) != 1 or VERSION.findall(match["body"]) != [version]:
            raise ValueError("Main's app version/settings changed; uploaded build was not written back")
        current.append(int(numbers[0][2]))
    if max(current) > int(number):
        return source, "Main already contains a newer build number; no changes made"
    result = source
    for match in reversed(configurations):
        body = BUILD.sub(lambda setting: setting[1] + number + setting[3], match["body"])
        result = result[:match.start("body")] + body + result[match.end("body"):]
    return result, "Prepared app build-number update" if result != source else "Build number already recorded; no changes made"


def main():
    if len(sys.argv) != 4:
        raise ValueError("Usage: record_build_number.py PROJECT_FILE UPLOADED_BUILD MARKETING_VERSION")
    path = Path(sys.argv[1])
    source = path.read_bytes().decode("utf-8")
    updated, message = updated_project(source, sys.argv[2], sys.argv[3])
    if updated != source:
        path.write_bytes(updated.encode("utf-8"))
    print(message)


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError) as error:
        sys.exit(f"Build-number write-back failed: {error}")
