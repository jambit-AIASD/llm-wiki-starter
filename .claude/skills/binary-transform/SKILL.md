---
name: binary-transform
description: >
  Convert a document in import/ to Markdown at its raw/ destination, using the
  appropriate vendored skill (pdf, pptx, docx, xlsx). Write the output file,
  then append a manifest entry. Never perform the wiki ingest itself.
---

# Binary → Markdown Transform

Convert `<input>` (a file under `import/`) to Markdown at `<output>` (under `raw/`,
extension appended: `spec.pptx` → `spec.pptx.md`).

## Procedure

1. Check the input file exists and note its extension.
2. Invoke the matching vendored skill for extraction only:
   - `.pdf` / `.htm` / `.html` → **pdf** skill: extract text using `pdftotext -layout`
     (preferred — preserves multi-column layouts and letter-spaced text correctly):
     ```bash
     pdftotext -layout '<input>' '<output>.txt'
     ```
     Wrap the `.txt` output in any required file header comments, then save as `.md`.
     Fall back to `uv run --with "markitdown[pdf]" markitdown '<input>'` only when
     `pdftotext` is unavailable or the PDF is scanned/image-only (pdftotext yields
     empty output).
   - `.pptx` → **pptx** skill: `uv run --with "markitdown[pptx]" markitdown '<input>'`
   - `.docx` → **docx** skill: pandoc extraction path (see docx skill — Converting to Markdown)
   - `.xlsx` → **xlsx** skill: text/table extraction via
     `uv run --with "markitdown[xlsx]" markitdown '<input>'`
3. Write the Markdown output to `<output>` (create parent dirs as needed).
   Spot-check the first ~50 lines: real sentences/tables, not extraction garbage.
   - Empty result (scanned/image-only PDF) → report clearly; do NOT fabricate content.
   - Report the character count on success.
4. Append a manifest entry to `ingest-manifest.jsonl` (repo root, one JSON line):
   ```json
   {"blob_path":"<blob>","import_path":"<input>","converted":"<output>","converted_at":"<ISO8601>","status":"converted","chars":<N>}
   ```
   Status values: `"converted"` (success), `"conversion_empty"` (empty output).
   Do NOT write an `"oversize_needs_review"` entry — the workflow verify gate handles
   oversize detection independently and writes that entry in bash.

## Constraints

- Output goes ONLY to the specified `raw/` path.
- Never modify anything in `wiki/` — that is the ingest's job.
- Never write content that did not come from the source file.
- Run everything through `uv run`; never call `pip` or system `python` directly.
- Do not split oversized files in CI — that is a manual recovery step.
