# Publish to TestFlight

One manually dispatched GitHub Actions job builds Meetrail on the Apple Silicon `xcode-27` runner, runs deterministic checks, archives Release with automatic signing, exports a Mac App Store `.pkg`, verifies it, and uploads it with Fastlane. No push/PR triggers, tags, GitHub Releases, signing repository, Match, Apple ID login, or external tester distribution. The existing app configuration and entitlements are preserved. `xcode-27` is currently a GitHub public-preview runner label.

**Publishing is not yet verified.** Local builds do not prove cloud distribution signing. No Team API Key was supplied for P16 and no upload was authorized. The first authorized clean-runner archive/export must establish whether this team and key can cloud sign both the app and the installer without imported identities. A failure stops the pipeline; there is no automatic fallback.

## Apple setup

1. The Account Holder must accept current agreements and have an active Apple Developer Program membership. Confirm the explicit macOS App ID `com.volrik.meetrail` belongs to Team `WX557M9HD2`, with the existing capabilities intact.
2. Create the **macOS** Meetrail application record in App Store Connect using that Bundle ID, a unique SKU, version **1.0**, and the **Productivity** category matching the app's `LSApplicationCategoryType`. P16 adds this previously missing required Mac App Store metadata; no capabilities change. The workflow never creates the app record or changes its marketing version.
3. In Users and Access → Integrations → App Store Connect API, request API access if needed. Create a **Team Key** with **Admin** access for automatic provisioning and distribution. Record its Key ID and Issuer ID and download its `.p8` once. Keep it outside the repository. Admin is broader than upload-only App Manager access, but this workflow also needs Certificates, Identifiers & Profiles access. Confirm cloud-managed distribution certificate access for the account/team. A successful read-only API preflight verifies provisioning endpoint access; successful archive/export is the definitive signing check.

An **Individual Apple Developer Program membership** is compatible with a one-person team; it is different from an **individual App Store Connect API key**. Individual keys have no Team Issuer ID and cannot use provisioning endpoints. They are not supported by this workflow. Team keys apply across the team's apps; protect this key accordingly.

## GitHub configuration

In the repository's Settings → Environments, create **`testflight`**. Restrict deployment branches to **Selected branches and tags → branch `main`** (do not permit tags). Add these Environment values:

| Kind | Name | Value |
| --- | --- | --- |
| Variable | `APPLE_TEAM_ID` | `WX557M9HD2` |
| Variable | `APP_IDENTIFIER` | `com.volrik.meetrail` |
| Secret | `ASC_KEY_ID` | Team API Key ID |
| Secret | `ASC_ISSUER_ID` | Team API Key Issuer UUID |
| Secret | `ASC_API_KEY_P8` | Original complete multiline private `.p8` content, including the BEGIN/END PRIVATE KEY lines |

Copy the original file to the macOS clipboard without printing the key in terminal output:

```sh
pbcopy < /secure/path/AuthKey_YOURKEYID.p8
```

Paste into the `testflight` Environment secret `ASC_API_KEY_P8`, preserving real line breaks, then clear the clipboard. Replace the previous encoded secret with this raw secret; do not encode it or replace newlines with literal `\n` characters. Do not place keys, tokens, certificates, `.env` files, packages, archives, logs, or real account data in Git. The workflow writes the exact content with `printf '%s'` to a temporary `.p8` file and sets mode `0600` inside a mode `0700` directory. `ASC_API_KEY_PATH` is an internal workflow-generated path, not another GitHub secret. Xcode uses that file; Fastlane uses the same raw secret via `key_content` and `is_key_content_base64: false`. Ruby `ensure`, the shell EXIT trap and an always-run cleanup step remove temporary credentials on failure. The hosted VM is disposable if forcibly terminated. No packages, logs, or signing diagnostics are uploaded as GitHub artifacts.

Optionally configure an Environment reviewer to require owner approval before credentials are released. The workflow itself has `contents: read`, disables checkout credential persistence, checks `main` again in the publishing lane, and uses fixed concurrency with `cancel-in-progress: false`. GitHub may replace an older **pending** run when several are queued; a running upload is never canceled by concurrency.

## Local dependencies and validation

Use Xcode 27, macOS supporting that Xcode, and Ruby **3.4.x** (not Apple's system Ruby 2.6). Fastlane **2.241.1** and its complete dependency graph are locked. For example, using an existing rbenv installation:

```sh
rbenv install --skip-existing "$(rbenv install -l | awk '$1 ~ /^3\.4\.[0-9]+$/ {version=$1} END {print version}')"
export RBENV_VERSION="$(rbenv versions --bare | awk '/^3\.4\.[0-9]+$/ {version=$1} END {print version}')"
gem install bundler -v 2.6.3
bundle install
bundle exec fastlane lanes
python3 Tools/verify-architecture.py
ruby -c fastlane/Fastfile
ruby -c fastlane/Appfile
bundle exec ruby fastlane/ci_support_test.rb
python3 -m unittest discover -s fastlane -p '*_test.py'
bundle exec fastlane mac verify
git diff --check
```

`verify` never authenticates to Apple or uploads. Locally it uses the existing automatic development identity for Debug/tests and Release. On GitHub Actions it uses an ad-hoc **Debug test host only** and an unsigned Release **build check only**, so no credentials are needed for checks. Neither output can reach TestFlight. Production `beta` archives with normal automatic signing; it does not disable signing, override identities, or clear entitlements.

The unit target runs with two deliberate environment-dependent exclusions: `CalendarIntegrationTests` requires calendar consent and standalone QA fixtures, and `StabilizationTests/realStructuredInferenceAndUnsupportedLanguage()` requires a ready Apple Intelligence model. No test source was changed. The remaining tests cover domain logic, persistence with synthetic/in-memory or temporary stores, ViewModels, provider isolation, and AI mocks; mocks do not verify live services. GUI tests are manual on a reliable logged-in Mac. CI does not prove real EventKit accounts, AI inference, conference services, or macOS 15 runtime compatibility. See [VALIDATION.md](VALIDATION.md).

## First GitHub Actions run

1. Review and merge these files onto `main` through the owner's normal process. P16 did not create a branch, commit, push, tag, or release.
2. Complete the Apple setup and the `testflight` Environment configuration above.
3. After explicitly authorizing a real upload, open Actions → **Publish to TestFlight** → Run workflow → choose **main** → Run workflow. Do not dispatch from another branch. There are no inputs. This invokes `bundle exec fastlane mac beta` after the checks.
4. Inspect the separate stage results in the run summary and expandable log groups: Debug build, unit tests, Release build, configuration/API preflight, build number, Release archive, automatic signing/export, package verification, upload.
5. In App Store Connect → Meetrail → TestFlight → macOS, find the reported **1.0 (build)**. An upload-success result means Apple accepted the transfer, **not** that processing completed or testers can install it. Wait for processing, resolve any compliance information or processing errors, then confirm internal availability. Configure tester access manually. The lane neither submits App Store review nor external beta review, and does not add tester groups.

The build number is an integer `GITHUB_RUN_ID * 1000 + GITHUB_RUN_ATTEMPT` (attempts 1–999), checked against `latest_testflight_build_number(platform: "osx", version: "1.0", initial_build_number: 0)`. This gives distinct numbers on reruns even while a previous upload is processing. Lookup errors propagate; only a successful empty result means a first upload. If an out-of-band build number is already at or ahead of the candidate, publishing fails for manual numbering review rather than choosing a potentially duplicate number. Keep publishing serialized through this workflow. `CURRENT_PROJECT_VERSION` is passed to `xcodebuild` only; no project edits are committed. Marketing version stays 1.0 and Xcode's export renumbering is disabled.

## Signing and export decisions

Installed Xcode **27.0 (27A266a)** `xcodebuild -help` lists **`app-store-connect`**; `app-store` is deprecated. Export uses `destination=export`, `signingStyle=automatic`, the Team ID, and `manageAppVersionAndBuildNumber=false`. Both archive and export receive `-allowProvisioningUpdates`, `-authenticationKeyPath`, `-authenticationKeyID`, and `-authenticationKeyIssuerID`. Xcode may manage provisioning assets during an authorized publish. No separate `cert`, `sigh`, Match, certificate rotation or revocation action is used.

Fastlane `build_mac_app` orchestrates the archive. Export calls `xcodebuild -exportArchive` directly to avoid gym's legacy export-method defaults/validation. `upload_to_testflight(pkg: ..., app_platform: "osx", skip_submission: true, skip_waiting_for_build_processing: true)` uploads the actual verified package. It does not use an iOS `.ipa`.

An unsigned archive experiment succeeded locally but contained no entitlement metadata or team signature. Fastlane's `skip_codesigning` also clears `CODE_SIGN_ENTITLEMENTS`. Neither approach is used for publishing. Cloud-managed **distribution** signing does not by itself prove that Xcode can create the **archive** without a local development identity. The clean runner must verify this distinction. Apple documents cloud signing for distribution, but account access and support for the separate Mac Installer Distribution signature must also be established in the authorized run.

The archive check verifies the bundle ID, version/build, menu-bar `LSUIElement`, calendar usage description, signed Team ID, Hardened Runtime, sandbox/calendar/file-selection entitlements and absence of development/debugging entitlements. Package verification checks a trusted **Mac Installer Distribution** signature for this team, expands the package without installing it, and repeats app checks against the **actual package payload**, requiring a Mac App Store application distribution signature. Unexpected capabilities fail for review. An archive may have a development signature; only the exported package is a distribution deliverable.

## Failures and the minimal identity fallback

| Failure stage | Investigate before changing anything |
| --- | --- |
| API preflight / 401 / 403 | Team versus individual key, issuer/key pairing, intact raw PEM content and line breaks, Admin role, provisioning access, expired/revoked key and agreements. |
| App lookup / App ID | macOS app record, exact Bundle ID, correct team, explicit App ID registration and existing capabilities. |
| Archive / `No signing certificate ... Mac Development` | Archive needs a local development identity/private key; cloud distribution export has not run yet. Preserve the exact diagnostic. |
| Export / cloud signing access | Cloud-managed certificate access and provisioning permissions; inspect Xcode distribution diagnostics privately. |
| Export / missing Mac App Distribution or Apple Distribution | Determine whether this Xcode/team/key can cloud sign the app or requires an existing local app distribution identity. |
| Export / missing Mac Installer Distribution | The installer `.pkg` needs its own distribution signature; an app signing identity is insufficient. |
| Export / invalid method or missing `.pkg` | Inspect this runner's `xcodebuild -help`, selected Xcode and export logs; never substitute Developer ID, ad-hoc, or `.ipa` distribution. |
| Verification | Compare actual signed payload entitlements and identities; do not remove sandbox/calendar capabilities or bypass the check. |
| Upload / processing | Correct macOS app record, increasing build number, Apple service status, package validation messages and compliance information. |

If a **verified** failure requires local signing assets, first obtain the owner's approval for a targeted fallback change. Export only the **existing** required identity/private key as password-protected `.p12` from the owner's Keychain: development identity for an archive failure, application distribution identity for app export, and/or **Mac Installer Distribution** for installer export. Never create/revoke certificates as a shortcut. Do not use the unused signing repository or Match. No fallback secrets are required or consumed by the current workflow.

The minimal fallback would add two Environment secrets, `SIGNING_P12_BASE64` and `SIGNING_P12_PASSWORD`, and a CI-only import before `beta`; leave automatic provisioning enabled. One encrypted `.p12` can contain the specifically required identities. Generate the temporary keychain password at runtime. The following is an implementation recipe **only after diagnosis and approval**, with those secrets mapped to environment variables; integrate it into the publishing shell so the trap survives through `beta`:

```bash
set -euo pipefail
umask 077
CI_SIGNING_DIR="$(mktemp -d "$RUNNER_TEMP/meetrail-signing.XXXXXX")"
CI_KEYCHAIN="$CI_SIGNING_DIR/signing.keychain-db"
CI_KEYCHAIN_PASSWORD="$(openssl rand -hex 32)"
original_keychains=()
while IFS= read -r path; do original_keychains+=("$path"); done < <(
  security list-keychains -d user | sed -E 's/^[[:space:]]*"|"[[:space:]]*$//g'
)
cleanup_signing() {
  security list-keychains -d user -s "${original_keychains[@]}"
  security delete-keychain "$CI_KEYCHAIN" >/dev/null 2>&1 || true
  rm -rf -- "$CI_SIGNING_DIR"
}
trap cleanup_signing EXIT
printf '%s' "$SIGNING_P12_BASE64" | base64 --decode > "$CI_SIGNING_DIR/identities.p12"
security create-keychain -p "$CI_KEYCHAIN_PASSWORD" "$CI_KEYCHAIN"
security set-keychain-settings -lut 3600 "$CI_KEYCHAIN"
security unlock-keychain -p "$CI_KEYCHAIN_PASSWORD" "$CI_KEYCHAIN"
security import "$CI_SIGNING_DIR/identities.p12" -k "$CI_KEYCHAIN" \
  -P "$SIGNING_P12_PASSWORD" -T /usr/bin/codesign -T /usr/bin/productbuild
security set-key-partition-list -S apple-tool:,apple:,codesign: \
  -s -k "$CI_KEYCHAIN_PASSWORD" "$CI_KEYCHAIN" >/dev/null
security list-keychains -d user -s "$CI_KEYCHAIN" "${original_keychains[@]}"
bundle exec fastlane mac beta
```

Add an always-run keychain/temp cleanup as well when integrating this recipe. Do not enable shell tracing. Retain provisioning downloads through the Team API Key; manually managed profiles are not a default. If Xcode requires a manually managed profile, diagnose it separately and document the exact capability and compatibility implications before proceeding.

## References checked for P16

- [Apple cloud-managed certificates](https://developer.apple.com/help/account/certificates/cloud-managed-certificates/) and [automating cloud signing with xcodebuild (WWDC21)](https://developer.apple.com/videos/play/wwdc2021/10204/).
- [Apple App Store Connect API keys](https://developer.apple.com/help/app-store-connect/get-started/app-store-connect-api/) and [creating distribution-signed Mac code](https://developer.apple.com/documentation/xcode/creating-distribution-signed-code-for-the-mac/).
- [GitHub hosted runner labels](https://docs.github.com/en/actions/how-tos/write-workflows/choose-where-workflows-run/choose-the-runner-for-a-job), [Fastlane macOS build action](https://docs.fastlane.tools/actions/build_mac_app/), [build lookup](https://docs.fastlane.tools/actions/latest_testflight_build_number/) and [pilot upload options](https://docs.fastlane.tools/actions/pilot/).
