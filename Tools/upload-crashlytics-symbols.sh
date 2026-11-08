#!/bin/sh
# The last Xcode build phase has the dSYM and app resources available.
set -eu
if [ "${KAIGI_CRASHLYTICS_VALIDATE_SYMBOLS_ONLY:-NO}" = YES ]; then
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
if [ ! -x "$uploader" ]; then
    echo "error: Firebase SPM upload-symbols is missing. See Docs/Crashlytics.md."
    exit 1
fi

# Run the same uploader as Firebase's run script in the foreground so Xcode
# receives its exit status. Build-phase mode keeps Firebase's dSYM deduplication.
exec "$uploader" "$@"
