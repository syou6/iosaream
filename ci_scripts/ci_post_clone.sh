#!/bin/zsh
# Xcode Cloud post-clone script.
# Runs after Xcode Cloud clones the repo, before any build/test steps.
# Use this to materialise xcconfig secrets from environment variables that
# you configured in App Store Connect under "Environment Variables and
# Secrets" for the workflow.

set -euo pipefail

mkdir -p Config
cat > Config/Secrets.xcconfig <<EOF
SUPABASE_URL = ${SUPABASE_URL:-}
SUPABASE_ANON_KEY = ${SUPABASE_ANON_KEY:-}
REVENUECAT_API_KEY = ${REVENUECAT_API_KEY:-}
POSTHOG_API_KEY = ${POSTHOG_API_KEY:-}
SENTRY_DSN = ${SENTRY_DSN:-}
EOF

echo "Wrote Config/Secrets.xcconfig"
echo "Swift version: $(swift --version || true)"
