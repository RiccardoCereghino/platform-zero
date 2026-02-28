#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────
# upstream-sync.sh — Diff & merge upstream module changes
# ──────────────────────────────────────────────────────────────
# Since we own the raw .tf files (Option B), this script helps
# track what upstream has changed so you can cherry-pick updates.
#
# Usage:
#   ./scripts/upstream-sync.sh          # Show diff against latest upstream
#   ./scripts/upstream-sync.sh v4.9.0   # Show diff against specific tag
#   ./scripts/upstream-sync.sh apply    # Fetch and create a patch file
# ──────────────────────────────────────────────────────────────

set -euo pipefail

UPSTREAM_REPO="https://github.com/hcloud-k8s/terraform-hcloud-kubernetes.git"
UPSTREAM_DIR="/tmp/hcloud-k8s-upstream"
INFRA_DIR="$(cd "$(dirname "$0")/../infrastructure" && pwd)"
PATCH_DIR="$(cd "$(dirname "$0")/.." && pwd)/patches"

# Files we added locally that don't exist upstream
LOCAL_ONLY_FILES=(
  "terraform.tfvars"
  ".gitignore"
)

fetch_upstream() {
  local ref="${1:-main}"

  echo "📥 Fetching upstream (ref: ${ref})..."
  if [ -d "$UPSTREAM_DIR" ]; then
    rm -rf "$UPSTREAM_DIR"
  fi
  git clone --depth 1 --branch "$ref" "$UPSTREAM_REPO" "$UPSTREAM_DIR" 2>/dev/null
  rm -rf "$UPSTREAM_DIR/.git"
  echo "   ✓ Cloned to $UPSTREAM_DIR"
}

build_excludes() {
  local excludes=""
  for f in "${LOCAL_ONLY_FILES[@]}"; do
    excludes+=" --exclude=$f"
  done
  echo "$excludes"
}

show_diff() {
  local ref="${1:-main}"
  fetch_upstream "$ref"

  echo ""
  echo "📊 Comparing local infrastructure/ against upstream ($ref)..."
  echo "─────────────────────────────────────────────────────────"

  local excludes
  excludes=$(build_excludes)

  # diff returns 1 if there are differences, so we || true
  diff -rq $excludes "$UPSTREAM_DIR" "$INFRA_DIR" 2>/dev/null || true

  echo ""
  echo "─────────────────────────────────────────────────────────"
  echo "📝 For a full patch, run: $0 apply $ref"
}

create_patch() {
  local ref="${1:-main}"
  fetch_upstream "$ref"

  mkdir -p "$PATCH_DIR"
  local patch_file="$PATCH_DIR/upstream-$(date +%Y%m%d)-${ref}.patch"

  local excludes
  excludes=$(build_excludes)

  echo "📝 Generating patch..."
  diff -ru $excludes "$INFRA_DIR" "$UPSTREAM_DIR" > "$patch_file" 2>/dev/null || true

  if [ -s "$patch_file" ]; then
    echo "   ✓ Patch saved to: $patch_file"
    echo ""
    echo "To review:  less $patch_file"
    echo "To apply:   cd $INFRA_DIR && patch -p1 --dry-run < $patch_file"
    echo "To commit:  cd $INFRA_DIR && patch -p1 < $patch_file"
  else
    echo "   ✓ No differences found. You're up to date!"
    rm -f "$patch_file"
  fi
}

# ── Main ──────────────────────────────────────────────────────
case "${1:-}" in
  apply)
    create_patch "${2:-main}"
    ;;
  -h|--help)
    echo "Usage: $0 [tag|apply [tag]]"
    echo ""
    echo "  (no args)     Show diff summary against upstream main"
    echo "  v4.9.0        Show diff summary against tag v4.9.0"
    echo "  apply         Generate a patch file from upstream main"
    echo "  apply v4.9.0  Generate a patch file from tag v4.9.0"
    ;;
  *)
    show_diff "${1:-main}"
    ;;
esac
