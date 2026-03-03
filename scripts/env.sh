#!/usr/bin/env bash
# Load SOPS-encrypted environment variables into the current shell.
# Usage: source scripts/env.sh
#
# Replaces the previous direnv + 1Password CLI integration.
# Requires: sops, age, and SOPS_AGE_KEY set (or key in default age keyfile).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
SECRETS_FILE="$REPO_ROOT/secrets/local.env.yaml"

if [[ ! -f "$SECRETS_FILE" ]]; then
  echo "Error: $SECRETS_FILE not found." >&2
  echo "See SOPS.md for setup instructions." >&2
  return 1 2>/dev/null || exit 1
fi

set -a
eval "$(sops --decrypt --output-type dotenv "$SECRETS_FILE")"
set +a
