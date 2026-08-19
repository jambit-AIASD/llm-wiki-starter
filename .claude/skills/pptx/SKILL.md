---
name: pptx
description: "Use this skill any time a .pptx file is involved in any way — as input, output, or both. This includes: creating slide decks, pitch decks, or presentations; reading, parsing, or extracting text from any .pptx file (even if the extracted content will be used elsewhere, like in an email or summary); editing, modifying, or updating existing presentations; combining or splitting slide files; working with templates, layouts, speaker notes, or comments. Trigger whenever the user mentions \"deck,\" \"slides,\" \"presentation,\" or references a .pptx filename, regardless of what they plan to do with the content afterward. If a .pptx file needs to be opened, created, or touched, use this skill."
license: Proprietary. LICENSE.txt has complete terms
---

# PPTX Skill

## Setup

Before running any Node.js script, ensure dependencies are installed:

```bash
# Run once — skip if node_modules/ already exists in this skill directory
SKILL_DIR="$(dirname "$0")"   # or use the absolute path to .claude/skills/pptx/
[ -d "$SKILL_DIR/node_modules" ] || npm install --prefix "$SKILL_DIR"
```

In practice: check for `.claude/skills/pptx/node_modules/` and run `npm install` in that directory if it is absent. The `package.json` there lists all required packages.

---

## Quick Reference

| Task | Guide |
|------|-------|
| Read/analyze content | `uv run --with "markitdown[pptx]" markitdown presentation.pptx` |
| Edit or create from template | Read [editing.md](editing.md) |
| Create from scratch | Read [pptxgenjs.md](pptxgenjs.md) |

---

## Reading Content

```bash
# Text extraction
uv run --with "markitdown[pptx]" markitdown presentation.pptx

# Visual overview
uv run --with Pillow python .claude/skills/pptx/scripts/thumbnail.py presentation.pptx

# Raw XML
uv run python .claude/skills/pptx/scripts/office/unpack.py presentation.pptx unpacked/
```

### Converting to Markdown (with images)

pandoc supports pptx input and `--extract-media`, so the same pattern as docx applies. Derive three values from the conversion request:

| Variable | Derive from | Default when not specified |
|---|---|---|
| `OUTPUT_MD` | The requested output path (absolute) | Input filename + `.md` in same dir as input |
| `IMAGES_DIR` | Absolute path of the folder that should contain images | Directory containing `OUTPUT_MD` |
| `IMAGES_REL` | Relative path from the `.md` file's directory to `IMAGES_DIR` | `media` (when `IMAGES_DIR` is the same folder) |

```bash
# Example: input at /project/docs/inputs/deck.pptx, output to /project/docs/deck.md, images in /project/docs/media
OUTPUT_MD="/project/docs/deck.md"
IMAGES_DIR="/project/docs"      # pandoc creates /project/docs/media/ here
IMAGES_REL="media"

pandoc input.pptx -o "$OUTPUT_MD" --wrap=none --extract-media="$IMAGES_DIR"

# Fix 1: absolute paths → relative, then URL-encode path components
# Use Python (not sed) — paths contain & and spaces which break sed,
# and markdown renderers require URL-encoded paths (spaces → %20, & → %26)
uv run --quiet python3 - "$OUTPUT_MD" "$IMAGES_DIR/media/" "$IMAGES_REL/" <<'PYEOF'
import sys, re
from urllib.parse import quote
path, old, new = sys.argv[1], sys.argv[2], sys.argv[3]

def url_encode_path(p):
    return '/'.join(quote(part, safe='') if part not in ('', '..', '.') else part
                    for part in p.split('/'))

text = open(path).read()
text = text.replace(old, new)
text = re.sub(r'!\[\]\(([^)]+)\)', lambda m: '![](' + url_encode_path(m.group(1)) + ')', text)
open(path, 'w').write(text)
PYEOF

# Fix 2: strip pandoc dimension attributes
sed -i '' 's/{width="[^"]*" height="[^"]*"}//g' "$OUTPUT_MD"
```

**llm-wiki layout:** markdown files live under `raw/` (optionally in topical subfolders, e.g. `raw/<topic>/file.md`). Images go under `raw/assets/` mirroring the same folder structure, with the filename slugified as the final subdirectory, so they stay organised alongside the source files.

Derive a slug from the source filename: lowercase, replace `.` and spaces with `-`.
Example: `deck.pptx` → slug `deck-pptx`

```bash
SLUG=$(echo "<source-filename>" | tr '[:upper:]' '[:lower:]' | tr '. ' '-')
OUTPUT_MD="/abs/repo/raw/<topic>/<source-filename>.md"
IMAGES_DIR="/abs/repo/raw/assets/<topic>/$SLUG"
# pandoc creates $IMAGES_DIR/media/imageN.png
# from <topic>/ → up to raw/, then down into assets/<topic>/<slug>/media
IMAGES_REL="../assets/<topic>/$SLUG/media"
```

---

## Converting from DOCX

When the source material is a Word document, extract both text and visuals before building slides:

```bash
# Extract text
uv run --with "markitdown[pptx]" markitdown source.docx

# Extract embedded images (diagrams, charts, figures)
uv run python .claude/skills/pptx/scripts/office/unpack.py source.docx unpacked-docx/
# Images are in unpacked-docx/word/media/
```

**Diagrams, charts, and images from the source document must always be included in the presentation.** Do not reduce the docx to text-only slides. For each visual in the source:

- **Embedded charts** — recreate as a native pptx chart or replace with a slide that calls out the key stat/finding prominently.
- **Diagrams and figures** — embed the extracted image (`slide.shapes.add_picture(...)`) or redraw as shapes if the image quality is too low.
- **Tables** — convert to a styled table shape or a visual comparison layout; never drop them.

Check for visuals explicitly — markitdown strips images, so always inspect `word/media/` for anything that didn't appear in the text extraction.

---

## Editing Workflow

**Read [editing.md](editing.md) for full details.**

1. Analyze template with `thumbnail.py`
2. Unpack → manipulate slides → edit content → clean → pack

---

## Creating from Scratch

**Read [pptxgenjs.md](pptxgenjs.md) for full details.**

Use when no template or reference presentation is available.

**Before writing the script**, ensure `node_modules/` exists in `.claude/skills/pptx/` (see Setup above). Run your script with:

```bash
node --experimental-require-module generate.js
# or simply
node generate.js   # if the script uses require()
```

Set `NODE_PATH` to the skill's `node_modules` if running the script from a different directory:

```bash
NODE_PATH=/path/to/.claude/skills/pptx/node_modules node generate.js
```

---

## Working with .potx Template Files

`.potx` files are PowerPoint templates — python-pptx and the unpack script reject them because they carry a different content type than `.pptx`. **Do not rename or copy them to `.pptx`.**

If the project provides a helper (look for `scripts/open_template.py` or similar), use it:

```python
import sys
sys.path.insert(0, '.')
from scripts.open_template import open_potx

prs = open_potx("templates/my_template.potx")
# prs is a live Presentation with 0 slides, all layouts/masters intact
prs.save("output.pptx")
```

If no helper exists, patch the content type yourself:

```python
import io, zipfile, re
from pptx import Presentation

def open_potx(path):
    with zipfile.ZipFile(path, "r") as z:
        files = {n: z.read(n) for n in z.namelist()}
    ct = files["[Content_Types].xml"].decode("utf-8")
    files["[Content_Types].xml"] = ct.replace(
        "presentationml.template.main+xml",
        "presentationml.presentation.main+xml",
    ).encode("utf-8")
    # Strip embedded slides so you start with 0 slides
    slide_keys = [k for k in files if k.startswith("ppt/slides/")]
    for k in slide_keys:
        del files[k]
    ct2 = files["[Content_Types].xml"].decode("utf-8")
    ct2 = re.sub(r'<Override PartName="/ppt/slides/[^"]*"[^/]*/>', "", ct2)
    files["[Content_Types].xml"] = ct2.encode("utf-8")
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, "w", zipfile.ZIP_DEFLATED) as z:
        for name, data in files.items():
            z.writestr(name, data)
    buf.seek(0)
    return Presentation(buf)
```

---

## Design Ideas

**Don't create boring slides.** Plain bullets on a white background won't impress anyone. Consider ideas from this list for each slide.

### Before Starting

- **Pick a bold, content-informed color palette**: The palette should feel designed for THIS topic. If swapping your colors into a completely different presentation would still "work," you haven't made specific enough choices.
- **Dominance over equality**: One color should dominate (60-70% visual weight), with 1-2 supporting tones and one sharp accent. Never give all colors equal weight.
- **Dark/light contrast**: Dark backgrounds for title + conclusion slides, light for content ("sandwich" structure). Or commit to dark throughout for a premium feel.
- **Commit to a visual motif**: Pick ONE distinctive element and repeat it — rounded image frames, icons in colored circles, thick single-side borders. Carry it across every slide.

### Color Palettes

Choose colors that match your topic — don't default to generic blue. Use these palettes as inspiration:

| Theme | Primary | Secondary | Accent |
|-------|---------|-----------|--------|
| **Midnight Executive** | `1E2761` (navy) | `CADCFC` (ice blue) | `FFFFFF` (white) |
| **Forest & Moss** | `2C5F2D` (forest) | `97BC62` (moss) | `F5F5F5` (cream) |
| **Coral Energy** | `F96167` (coral) | `F9E795` (gold) | `2F3C7E` (navy) |
| **Warm Terracotta** | `B85042` (terracotta) | `E7E8D1` (sand) | `A7BEAE` (sage) |
| **Ocean Gradient** | `065A82` (deep blue) | `1C7293` (teal) | `21295C` (midnight) |
| **Charcoal Minimal** | `36454F` (charcoal) | `F2F2F2` (off-white) | `212121` (black) |
| **Teal Trust** | `028090` (teal) | `00A896` (seafoam) | `02C39A` (mint) |
| **Berry & Cream** | `6D2E46` (berry) | `A26769` (dusty rose) | `ECE2D0` (cream) |
| **Sage Calm** | `84B59F` (sage) | `69A297` (eucalyptus) | `50808E` (slate) |
| **Cherry Bold** | `990011` (cherry) | `FCF6F5` (off-white) | `2F3C7E` (navy) |

### For Each Slide

**Every slide needs a visual element** — image, chart, icon, or shape. Text-only slides are forgettable.

**Layout options:**
- Two-column (text left, illustration on right)
- Icon + text rows (icon in colored circle, bold header, description below)
- 2x2 or 2x3 grid (image on one side, grid of content blocks on other)
- Half-bleed image (full left or right side) with content overlay

**Data display:**
- Large stat callouts (big numbers 60-72pt with small labels below)
- Comparison columns (before/after, pros/cons, side-by-side options)
- Timeline or process flow (numbered steps, arrows)

**Visual polish:**
- Icons in small colored circles next to section headers
- Italic accent text for key stats or taglines

### Typography

**Choose an interesting font pairing** — don't default to Arial. Pick a header font with personality and pair it with a clean body font.

| Header Font | Body Font |
|-------------|-----------|
| Georgia | Calibri |
| Arial Black | Arial |
| Calibri | Calibri Light |
| Cambria | Calibri |
| Trebuchet MS | Calibri |
| Impact | Arial |
| Palatino | Garamond |
| Consolas | Calibri |

| Element | Size |
|---------|------|
| Slide title | 36-44pt bold |
| Section header | 20-24pt bold |
| Body text | 14-16pt |
| Captions | 10-12pt muted |

### Spacing

- 0.5" minimum margins
- 0.3-0.5" between content blocks
- Leave breathing room—don't fill every inch

### Avoid (Common Mistakes)

- **Don't repeat the same layout** — vary columns, cards, and callouts across slides
- **Don't center body text** — left-align paragraphs and lists; center only titles
- **Don't skimp on size contrast** — titles need 36pt+ to stand out from 14-16pt body
- **Don't default to blue** — pick colors that reflect the specific topic
- **Don't mix spacing randomly** — choose 0.3" or 0.5" gaps and use consistently
- **Don't style one slide and leave the rest plain** — commit fully or keep it simple throughout
- **Don't create text-only slides** — add images, icons, charts, or visual elements; avoid plain title + bullets
- **Don't forget text box padding** — when aligning lines or shapes with text edges, set `margin: 0` on the text box or offset the shape to account for padding
- **Don't use low-contrast elements** — icons AND text need strong contrast against the background; avoid light text on light backgrounds or dark text on dark backgrounds
- **NEVER use accent lines under titles** — these are a hallmark of AI-generated slides; use whitespace or background color instead

---

## QA (Required)

**Assume there are problems. Your job is to find them.**

Your first render is almost never correct. Approach QA as a bug hunt, not a confirmation step. If you found zero issues on first inspection, you weren't looking hard enough.

### Content QA

```bash
uv run --with "markitdown[pptx]" markitdown output.pptx
```

Check for missing content, typos, wrong order.

**When using templates, check for leftover placeholder text:**

```bash
uv run --with "markitdown[pptx]" markitdown output.pptx | grep -iE "xxxx|lorem|ipsum|this.*(page|slide).*layout"
```

If grep returns results, fix them before declaring success.

### Visual QA

**⚠️ USE SUBAGENTS** — even for 2-3 slides. You've been staring at the code and will see what you expect, not what's there. Subagents have fresh eyes.

Convert slides to images (see [Converting to Images](#converting-to-images)), then use this prompt:

```
Visually inspect these slides. Assume there are issues — find them.

Look for:
- Overlapping elements (text through shapes, lines through words, stacked elements)
- Text overflow or cut off at edges/box boundaries
- Decorative lines positioned for single-line text but title wrapped to two lines
- Source citations or footers colliding with content above
- Elements too close (< 0.3" gaps) or cards/sections nearly touching
- Uneven gaps (large empty area in one place, cramped in another)
- Insufficient margin from slide edges (< 0.5")
- Columns or similar elements not aligned consistently
- Low-contrast text (e.g., light gray text on cream-colored background)
- Low-contrast icons (e.g., dark icons on dark backgrounds without a contrasting circle)
- Text boxes too narrow causing excessive wrapping
- Leftover placeholder content

For each slide, list issues or areas of concern, even if minor.

Read and analyze these images:
1. /path/to/slide-01.jpg (Expected: [brief description])
2. /path/to/slide-02.jpg (Expected: [brief description])

Report ALL issues found, including minor ones.
```

### Verification Loop

1. Generate slides → Convert to images → Inspect
2. **List issues found** (if none found, look again more critically)
3. Fix issues
4. **Re-verify affected slides** — one fix often creates another problem
5. Repeat until a full pass reveals no new issues

**Do not declare success until you've completed at least one fix-and-verify cycle.**

---

## Converting to Images

Run `qa.py` to generate the full QA artifact tree alongside the deck. The `qa/` folder is
created **next to the target file**, so:
- inspecting `docs/inputs/foo.pptx` → `docs/inputs/qa/`
- verifying `docs/generated/foo.pptx` → `docs/generated/qa/`

```bash
uv run .claude/skills/pptx/scripts/qa.py output.pptx
# → qa/libreoffice/output.pdf   (LibreOffice conversion)
# → qa/slides/slide-01.jpg ...  (per-slide renders at 150 dpi)
# → qa/report.json              (versions, slide count, exit codes)
```

The `qa/` folder is cleared and recreated on every run. Pass a second argument to override DPI:

```bash
uv run .claude/skills/pptx/scripts/qa.py output.pptx 200
```

To re-render specific slides after fixes:

```bash
pdftoppm -jpeg -r 150 -f N -l N qa/libreoffice/output.pdf qa/slides/slide-fixed
```

---

## Dependencies

**Node (pptxgenjs + icons):** declared in `package.json` — run `npm install` in this skill directory once:
```bash
npm install --prefix .claude/skills/pptx/
```

**Python tools:** use `uv run --with <pkg>` — no manual install needed:
- `uv run --with "markitdown[pptx]" markitdown` — text extraction
- `uv run --with Pillow python .claude/skills/pptx/scripts/thumbnail.py` — thumbnail grids

**System tools** (install separately if needed):
- LibreOffice (`soffice`) — PDF conversion for visual QA
- Poppler (`pdftoppm`) — PDF-to-image for visual QA
