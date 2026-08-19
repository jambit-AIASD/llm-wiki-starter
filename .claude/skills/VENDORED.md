# Vendored Skills

Skills in this directory are copied from [anthropics/skills](https://github.com/anthropics/skills).

| Skill | Upstream commit |
|-------|----------------|
| pptx  | 9d2f1ae187231d8199c64b5b762e1bdf2244733d |
| docx  | 9d2f1ae187231d8199c64b5b762e1bdf2244733d |
| xlsx  | 9d2f1ae187231d8199c64b5b762e1bdf2244733d |
| pdf   | 9d2f1ae187231d8199c64b5b762e1bdf2244733d |

To re-sync: clone `anthropics/skills`, diff each skill folder against the commit above,
review changes, copy updated folders here, and update the commit hashes.

After re-syncing, reapply the local customizations documented below.

---

## Local Customizations

These changes are NOT in the upstream vendor and must be reapplied after every re-sync.

### All skills — `python` → `uv run` + full script path prefix

Every bare `python` or `python3` command in the skill files has been replaced with `uv run`
because this project's Python environment is managed by uv. Bare `python` fails with
"command not found" on this machine.

**Critical: skill scripts must use the full path from project root.** When Claude runs Bash
from the project root (`/path/to/llm-wiki/`), `scripts/` resolves to `./scripts/`
relative to project root — NOT to `.claude/skills/pptx/scripts/`. The skills' script files
live at `.claude/skills/pptx/scripts/` and `.claude/skills/docx/scripts/` — always prefix
with the skill directory.

**Pattern to apply after re-sync (run from `.claude/skills/`):**

```bash
# Step 1: Replace bare python → uv run (content-aware replacements)
sed -i '' \
  -e 's|python -m markitdown|uv run --with "markitdown[pptx]" markitdown|g' \
  pptx/SKILL.md pptx/editing.md

# Step 2: Add skill directory prefix to all script/ paths (run from project root)
cd /path/to/llm-wiki
sed -i '' \
  -e 's|uv run --with Pillow python scripts/|uv run --with Pillow python .claude/skills/pptx/scripts/|g' \
  -e 's|uv run --with Pillow scripts/|uv run --with Pillow python .claude/skills/pptx/scripts/|g' \
  -e 's|uv run python scripts/|uv run python .claude/skills/pptx/scripts/|g' \
  -e 's|uv run scripts/|uv run .claude/skills/pptx/scripts/|g' \
  -e 's|python scripts/clean\.py|uv run .claude/skills/pptx/scripts/clean.py|g' \
  -e 's|python scripts/office/pack\.py|uv run .claude/skills/pptx/scripts/office/pack.py|g' \
  .claude/skills/pptx/editing.md .claude/skills/pptx/SKILL.md

sed -i '' 's|uv run scripts/|uv run .claude/skills/docx/scripts/|g' .claude/skills/docx/SKILL.md
```

---

### `docx/SKILL.md`, `pptx/SKILL.md`, `pdf/SKILL.md` — Added: Converting to Markdown (with images)

Section added to all three skills. Establishes a consistent three-variable pattern for
image extraction across all doc formats:

| Variable | Role |
|---|---|
| `OUTPUT_MD` | Absolute path of the output `.md` file |
| `IMAGES_DIR` | Absolute path of the folder images are extracted into |
| `IMAGES_REL` | Relative path from the `.md` file's directory to `IMAGES_DIR` — used in markdown image references (URL-encoded) |

**llm-wiki assets path:** images go under `raw/assets/` mirroring the source folder structure,
with the source filename slugified as the final subdirectory:
`raw/assets/<topic>/<slug>/`
Slug derivation: `tr '[:upper:]' '[:lower:]' | tr '. ' '-'` (spaces and dots → dashes).

**docx and pptx:** pandoc `--extract-media="$IMAGES_DIR"` extracts images (appends `media/`
subfolder). Fix 1 uses a Python heredoc (not sed — folder names may contain `&` and spaces
which are sed metacharacters) to replace absolute paths with `$IMAGES_REL/` and URL-encode
each path component (`%20`, `%26`, etc.) so markdown renderers resolve them correctly.
Fix 2 is a sed pass to strip `{width=... height=...}` attributes (no special chars, sed is fine).

**pdf:** `pdfimages -j input.pdf "$IMAGES_DIR/image"` extracts images directly into `IMAGES_DIR`
(no `media/` subfolder). Image placement in the markdown must be inserted manually.

**Re-sync reminder:** reapply these sections to all three SKILL.md files after every re-sync.

---

### `pptx/SKILL.md` — Added: Working with .potx Template Files

Section added after the "Creating from Scratch" block. Documents that `.potx` files carry a
different content type and must be opened via a content-type patch — either using
`scripts/open_template.py` (`open_potx()`) if the project provides it, or the self-contained
fallback snippet included in the section.

---

### `docx/SKILL.md` — Added: Working with .dotx Template Files

Section added before "Converting .doc to .docx". Same pattern as the pptx section: python-docx
rejects `.dotx` files; use `scripts/open_template.py` (`open_dotx()`) or the self-contained
fallback snippet.

---

### `pptx/scripts/office/soffice.py` and `docx/scripts/office/soffice.py` — auto `--outdir`

LibreOffice `--convert-to` writes output to its **working directory** when `--outdir` is not
supplied. The `__main__` block auto-injects `--outdir <input_file_dir>` whenever `--convert-to`
is present and `--outdir` is absent.

**Re-sync reminder:** upstream does not have this block — reapply after every re-sync.
