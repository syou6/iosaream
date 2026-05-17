#!/bin/zsh
# Xcode Cloud post-build script.
# Runs after every archive/build step. Use this to upload dSYMs and tag
# Sentry releases for non-PR workflows.

set -euo pipefail

if [[ "${CI_XCODEBUILD_ACTION:-}" != "archive" ]]; then
    echo "ci_post_xcodebuild: skipping (action=${CI_XCODEBUILD_ACTION:-unknown})"
    exit 0
fi

if [[ "${CI_WORKFLOW:-}" == "PR Check" ]]; then
    echo "ci_post_xcodebuild: skipping for PR workflow"
    exit 0
fi

if [[ -z "${SENTRY_AUTH_TOKEN:-}" || -z "${SENTRY_ORG:-}" || -z "${SENTRY_PROJECT:-}" ]]; then
    echo "ci_post_xcodebuild: Sentry env vars unset; skipping dSYM upload"
    exit 0
fi

if ! command -v sentry-cli >/dev/null 2>&1; then
    curl -sL https://sentry.io/get-cli/ | bash
fi

DSYM_PATH="${CI_ARCHIVE_PATH:-}/dSYMs"
if [[ -d "$DSYM_PATH" ]]; then
    sentry-cli upload-dif \
        --auth-token "$SENTRY_AUTH_TOKEN" \
        --org "$SENTRY_ORG" \
        --project "$SENTRY_PROJECT" \
        "$DSYM_PATH"
fi

if [[ -n "${CI_ARCHIVE_PATH:-}" ]]; then
    INFO_PLIST="${CI_ARCHIVE_PATH}/Info.plist"
    if [[ -f "$INFO_PLIST" ]]; then
        VERSION=$(defaults read "${INFO_PLIST%.plist}" CFBundleShortVersionString || echo "unknown")
        BUILD=$(defaults read "${INFO_PLIST%.plist}" CFBundleVersion || echo "unknown")
        RELEASE="okimission@${VERSION}+${BUILD}"
        sentry-cli releases new "$RELEASE" || true
        sentry-cli releases finalize "$RELEASE" || true
    fi
fi
