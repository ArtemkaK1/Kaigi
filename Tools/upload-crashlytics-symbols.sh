#!/bin/sh
# The last Xcode build phase has the dSYM and app resources available.
set -eu
if [ "${KAIGI_CRASHLYTICS_VALIDATE_SYMBOLS_ONLY:-NO}" = YES ]; then
    echo "Crashlytics: validating symbol inputs without uploading."
    set -- --build-phase --validate
elif [ "${CONFIGURATION:-}" = Release ] && [ "${KAIGI_CRASHLYTICS_UPLOAD_SYMBOLS:-NO}" = YES ]; then
    case "${ACTION:-}" in
        install|archive) set -- --build-phase ;;
        *) exit 0 ;;
    esac
    if [ -n "${XCTestConfigurationFilePath:-}" ] || [ -n "${XCTestBundlePath:-}" ]; then
        echo "error: Crashlytics symbol uploading is forbidden in XCTest."
        exit 1
    fi
else
    exit 0
fi

sdk="${FIREBASE_SPM_CHECKOUT_DIR:-${BUILD_DIR%/Build/*}/SourcePackages/checkouts/firebase-ios-sdk}"
uploader="$sdk/Crashlytics/upload-symbols"
if [ ! -f "$uploader" ] || [ ! -x "$uploader" ]; then
    printf 'error: Firebase SPM upload-symbols is missing or not executable at %s. Resolve packages or set FIREBASE_SPM_CHECKOUT_DIR to the Firebase checkout. See Docs/Crashlytics.md.\n' "$uploader" >&2
    exit 1
fi

# Run the same uploader as Firebase's run script in the foreground so Xcode
# receives its exit status. Build-phase mode keeps Firebase's dSYM deduplication.
exec "$uploader" "$@"
