#!/usr/bin/env bash
# scripts/sync-wiki.sh — Sync toolchain artifacts from a SOURCE checkout to a TARGET wiki repo.
#
# Usage (local):
#   ./scripts/sync-wiki.sh --source /path/to/wiki-base --target-repo myorg/wiki-instance --pat "$WIKI_PAT"
#   ./scripts/sync-wiki.sh --source /path/to/wiki-base --target-repo myorg/wiki-instance --pat "$WIKI_PAT" --dry-run
#
# Usage (CI — called by wiki-sync.yml):
#   bash scripts/sync-wiki.sh --source "$SRC_PATH" --target-repo "$TARGET" --pat "$PAT"

set -euo pipefail

SOURCE=""
TARGET_REPO=""
PAT=""
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --source)       SOURCE="$2";      shift 2 ;;
    --target-repo)  TARGET_REPO="$2"; shift 2 ;;
    --pat)          PAT="$2";         shift 2 ;;
    --dry-run)      DRY_RUN=true;     shift   ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

: "${SOURCE:?--source is required}"
: "${TARGET_REPO:?--target-repo is required}"
: "${PAT:?--pat is required}"

WORK_DIR=$(mktemp -d)
trap "rm -rf $WORK_DIR" EXIT

TGT="$WORK_DIR/target"
BRANCH="sync/toolchain-$(date -u +%Y%m%d)"

# ── Clone TARGET ──────────────────────────────────────────────────────────────
echo "==> Cloning $TARGET_REPO"
git clone "https://x-access-token:${PAT}@github.com/${TARGET_REPO}.git" "$TGT"

cd "$TGT"
git config user.email "github-actions[bot]@users.noreply.github.com"
git config user.name  "github-actions[bot]"

# Create or reset branch
if git ls-remote --exit-code --heads origin "$BRANCH" &>/dev/null; then
  git checkout "$BRANCH"
  git pull origin "$BRANCH"
else
  git checkout -b "$BRANCH"
fi
cd - > /dev/null

# ── rsync: whole directories ──────────────────────────────────────────────────
for dir in quartz scripts; do
  echo "==> $dir/"
  rsync -a --delete "$SOURCE/$dir/" "$TGT/$dir/"
done

# .github: workflows are shared toolchain artifacts.
echo "==> .github/"
rsync -a --delete "$SOURCE/.github/" "$TGT/.github/"

# .claude: exclude settings.local.json (instance-specific developer overrides)
echo "==> .claude/ (excluding settings.local.json)"
rsync -a --delete \
  --exclude='settings.local.json' \
  "$SOURCE/.claude/" "$TGT/.claude/"

# ── rsync: root-level files only ─────────────────────────────────────────────
# --filter='- */' prunes all subdirectories so only files at root level are touched.
# README.md is excluded: it always diverges per instance (domain-specific intro).
echo "==> root files"
rsync -a --delete \
  --exclude='.git'                  \
  --exclude='raw/'                  \
  --exclude='wiki/'                 \
  --exclude='import/'               \
  --exclude='*.jsonl'               \
  --exclude='.github/'              \
  --exclude='.claude/'              \
  --exclude='docs/'                 \
  --exclude='quartz/'               \
  --exclude='scripts/'              \
  --exclude='README.md'             \
  --filter='- */'                   \
  "$SOURCE/" "$TGT/"

# ── Detect changes ────────────────────────────────────────────────────────────
# git add -A first: untracked new files are invisible to `git diff` alone, so
# staging is required to catch adds/deletes/modifications uniformly.
cd "$TGT"
git add -A
if git diff --cached --quiet; then
  echo "==> No changes — TARGET is already in sync."
  exit 0
fi

if [ "$DRY_RUN" = "true" ]; then
  echo "==> Dry run — diff only:"
  git --no-pager diff --cached --stat
  git reset --quiet
  exit 0
fi

# ── Commit and push ───────────────────────────────────────────────────────────
CHANGED=$(git diff --cached --stat | tail -1)
git commit -m "sync: toolchain update from $(basename "$SOURCE") $(date -u +%Y-%m-%d)

Synced: .github/ .claude/ quartz/ scripts/ root-files
Not synced: raw/ wiki/ *.jsonl

Changes: $CHANGED"

git push origin "$BRANCH"

# ── Create or update PR ───────────────────────────────────────────────────────
export GH_TOKEN="$PAT"

EXISTING_PR=$(gh pr list \
  --repo "$TARGET_REPO" \
  --head "$BRANCH" \
  --json number \
  --jq '.[0].number' 2>/dev/null || true)

SOURCE_NAME=$(basename "$SOURCE")

if [ -n "$EXISTING_PR" ]; then
  echo "==> PR #$EXISTING_PR already open for $BRANCH — updated with new push."
else
  gh pr create \
    --repo "$TARGET_REPO" \
    --base main \
    --head "$BRANCH" \
    --title "sync: toolchain update from $SOURCE_NAME $(date -u +%Y-%m-%d)" \
    --body "$(cat <<'PREOF' | sed "s/__SOURCE__/$SOURCE_NAME/g"
## Toolchain Sync

Automated sync of non-domain artifacts from **__SOURCE__** (the SOURCE wiki).

### Paths synced (with delete)
- `.github/` — workflows
- `.claude/` — AI config and skills (excludes `settings.local.json`)
- `quartz/` — site generator source
- `scripts/` — helper scripts
- Root files: `CLAUDE.md`, `.gitignore`, `.mcp.json`, `package.json`, `quartz.config.yaml`, `pyproject.toml`, `uv.lock` (README.md excluded — diverges per instance)

### Paths NOT touched
- `raw/` — source documents (domain data, owned by this instance)
- `wiki/` — all wiki pages (domain data, owned by this instance)
- `*.jsonl` — per-instance conversion history (ingest-manifest.jsonl, etc.)

### Review checklist
- [ ] Workflow changes look intentional (no secrets, no hardcoded repo names)
- [ ] CLAUDE.md changes are backwards-compatible with existing ingest sessions
- [ ] Script changes are tested in SOURCE before merging here
PREOF
)"
fi

echo "==> Done. PR open on $TARGET_REPO at branch $BRANCH."
