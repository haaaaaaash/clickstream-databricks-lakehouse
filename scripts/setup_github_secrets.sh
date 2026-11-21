#!/bin/bash
# setup_github_secrets.sh: copies the values CI needs from .env into GitHub repository secrets
# Usage (from the repo root): bash scripts/setup_github_secrets.sh
# Prerequisite: GitHub CLI logged in (gh auth login); the repo has a GitHub remote
# The values are sent through stdin, so they never appear on screen or in the shell history.
# Safe to re-run: existing secrets are overwritten with the current values.
# References:
#   gh secret set:      https://cli.github.com/manual/gh_secret_set
#   Secrets in Actions: https://docs.github.com/actions/security-for-github-actions/security-guides/using-secrets-in-github-actions
set -euo pipefail

if [ ! -f .env ]; then echo "ERROR: .env not found. Run from the repo root."; exit 1; fi
set -a; source .env; set +a

echo "1. Checking the GitHub CLI..."
if ! command -v gh > /dev/null; then
  echo "   gh not installed -> installing (may ask for your sudo password)"
  sudo apt-get update -qq && sudo apt-get install -y gh
fi
gh auth status > /dev/null 2>&1 || gh auth login
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
echo "   repository: $REPO"

echo "2. Setting the repository secrets..."
for name in DATABRICKS_WORKSPACE_URL DATABRICKS_HTTP_PATH DATABRICKS_SP_CLIENT_ID DATABRICKS_SP_CLIENT_SECRET; do
  value="${!name:-}"
  if [ -z "$value" ]; then echo "ERROR: $name is empty in .env"; exit 1; fi
  printf '%s' "$value" | gh secret set "$name" --repo "$REPO"
  echo "   $name set"
done

echo "3. Secrets now in GitHub (names only, values are never shown):"
gh secret list --repo "$REPO"

echo
echo "Done. Push to main (or Actions > CI > Run workflow) to start the pipeline."
