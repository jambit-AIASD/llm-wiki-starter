# Document Tooling & Claude Code Skills

Reference for the document toolchain (LibreOffice, Poppler, Pandoc, Typst) and the
vendored Claude Code document skills.

---

## LibreOffice + Poppler + Pandoc + Typst

Used by the document skills to render Office files to images for visual QA, and (with pandoc + typst) to convert Markdown files to PDF — without these, generated PPTX and DOCX output cannot be inspected visually before review.

```bash
# macOS
brew install libreoffice poppler pandoc typst

# Linux (Debian/Ubuntu)
sudo apt install libreoffice poppler-utils pandoc
# typst: https://github.com/typst/typst/releases

# Windows
# LibreOffice: https://www.libreoffice.org/download/download/
# Poppler: https://github.com/oschwartz10612/poppler-windows/releases
# Pandoc: https://pandoc.org/installing.html
# Typst: https://github.com/typst/typst/releases
```

Usage in document generation scripts:

```bash
# Convert PPTX/DOCX to PDF
soffice --headless --convert-to pdf output.pptx

# Render PDF pages to individual JPEG images (150 DPI)
pdftoppm -jpeg -r 150 output.pdf slide
# Produces: slide-01.jpg, slide-02.jpg, ...

# Convert Markdown to PDF (preferred — no LaTeX required, full Unicode support)
pandoc input.md -o output.pdf --pdf-engine=typst --toc \
  --metadata title="Document Title"

# With custom table styling (alternating rows, custom font)
pandoc input.md -o output.pdf --pdf-engine=typst --toc \
  --include-in-header=style.typ --metadata title="Document Title"
```

> Required for the pptx and docx skill QA loops. Without them, visual layout issues (overflow, clipping, misaligned columns) go undetected until the file is opened in PowerPoint or Word.

---

## 🤖 Claude Code Skills

Document generation and editing is available directly in [Claude Code](https://claude.ai/code) coworker sessions via four vendored skills in `.claude/skills/`. **Claude Code must be installed** — skills only activate within a Claude Code session.

| Skill | Capability |
|-------|-----------|
| **pptx** | Create and edit PowerPoint decks; read via markitdown |
| **docx** | Create and edit Word documents; tracked-changes editing via OOXML |
| **xlsx** | Create and edit Excel workbooks, preserving formulas |
| **pdf** | Generate PDFs and manipulate existing ones (split/merge/forms) |

### One-time skill setup

The pptx and docx skills include Node.js helpers that must be installed once:

```bash
npm install --prefix .claude/skills/pptx/
npm install --prefix .claude/skills/docx/
```

Python helpers are covered by `uv sync` (see [README.md](./README.md)). All generated files land in `docs/generated/` by default.

### Usage

Skills activate automatically — just describe what you want in a prompt:

- *"Generate a management summary deck from the EcoRide risk analysis"*
- *"Edit this DOCX: mark section 3.2 as approved with tracked changes"*
- *"Export the tasks.json dependency graph as an Excel matrix"*

Skill scripts and their upstream version are tracked in [`.claude/skills/VENDORED.md`](./.claude/skills/VENDORED.md).

> Brand templates live in `templates/` — the skills use them automatically when directed to (`jambit-deck.potx`, `jambit-doc.dotx`).
