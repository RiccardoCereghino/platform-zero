#!/usr/bin/env bash
# Load SOPS-encrypted environment variables into the current shell.
# Usage: source scripts/env.sh
#
# Replaces the previous direnv + 1Password CLI integration.
#
# Bootstrap: sops resolves the age key in order:
#   1. $SOPS_AGE_KEY env var (if already set)
#   2. ~/.config/sops/age/keys.txt  (recommended — set this up once)
# See SOPS.md for first-time setup instructions.

# BASH_SOURCE for bash, ${(%):-%x} for zsh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-${(%):-%x}}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
SECRETS_FILE="$REPO_ROOT/secrets/local.env.yaml"

if [[ ! -f "$SECRETS_FILE" ]]; then
  echo "env.sh: secrets/local.env.yaml not found — see SOPS.md" >&2
  return 1
fi

# Ensure sops can find the age key
if [[ -z "$SOPS_AGE_KEY_FILE" && -f ~/.config/sops/age/keys.txt ]]; then
  export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt
fi

_sops_out="$(sops --decrypt --output-type dotenv "$SECRETS_FILE" 2>&1)"
if [[ $? -ne 0 ]]; then
  echo "env.sh: sops decryption failed:" >&2
  echo "$_sops_out" >&2
  echo "Hint: store your age key at ~/.config/sops/age/keys.txt" >&2
  unset _sops_out
  return 1
fi

set -a
eval "$_sops_out"
set +a

_var_count="$(grep -c '=' <<< "$_sops_out" 2>/dev/null || echo '?')"
unset _sops_out

echo "env.sh: loaded $_var_count variables from secrets/local.env.yaml"
