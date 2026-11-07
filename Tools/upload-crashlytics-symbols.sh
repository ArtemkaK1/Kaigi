#!/bin/sh
# Called by the final Xcode build phase. Upload is owner opt-in.
set -eu
# The official --validate branch exits before any upload/network work.
if [ "${KAIGI_CRASHLYTICS_VALIDATE_SYMBOLS_ONLY:-NO}" = YES ]; then
    sdk="${FIREBASE_SPM_CHECKOUT_DIR:-${BUILD_DIR%/Build/*}/SourcePackages/checkouts/firebase-ios-sdk}"
    exec "$sdk/Crashlytics/upload-symbols" --build-phase --validate
fi
if [ "${CONFIGURATION:-}" != Release ] || [ "${ACTION:-}" != install ] || [ "${KAIGI_CRASHLYTICS_UPLOAD_SYMBOLS:-NO}" != YES ]; then
    echo "Crashlytics symbols: skipped (requires opted-in Release install/archive)."
    exit 0
fi
if [ -n "${XCTestConfigurationFilePath:-}" ] || [ -n "${XCTestBundlePath:-}" ]; then
    echo "error: Crashlytics symbol uploading is forbidden in XCTest."
    exit 1
fi
sdk="${FIREBASE_SPM_CHECKOUT_DIR:-${BUILD_DIR%/Build/*}/SourcePackages/checkouts/firebase-ios-sdk}"
if [ ! -x "$sdk/Crashlytics/run" ]; then
    echo "error: Firebase SPM Crashlytics tooling is missing; see Docs/Crashlytics.md."
    exit 1
fi
# The pinned Firebase run script validates synchronously, then uploads in background.
# Do not invoke it at all for ordinary builds, tests, or offline validation.
exec "$sdk/Crashlytics/run"
