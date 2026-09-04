# Document Templates

Brand templates for the Claude Code document skills. Drop files here and the skills will use them automatically when directed.

## Expected Files

| File | Used by | Purpose |
|------|---------|---------|
| `jambit-deck.potx` | pptx skill | Master deck with jambit brand layouts, fonts, and colours |
| `jambit-doc.dotx` | docx skill | Word template with jambit house styles (headings, body, tables) |

## Opening Templates in Python

Both python-docx and python-pptx reject template content types (`.dotx`, `.potx`) directly.
Use the helpers in `scripts/open_template.py` instead:

```python
import sys; sys.path.insert(0, '.')   # run from repo root
from scripts.open_template import open_dotx, open_potx

doc = open_dotx("templates/jambit_doc.dotx")   # or open_potx() for .potx
# ... populate with content using template styles ...
doc.save("output.docx")

prs = open_potx("templates/jambit_deck.potx")
# ... add slides using template layouts ...
prs.save("output.pptx")
```

Both helpers patch the content type in memory — no temp files, no side effects.

## How to Use

Reference the template in your prompt — no path needed:

- *"Create a risk summary deck using the jambit deck template"*
- *"Generate a requirements document using the jambit doc template"*

The skill reads the template, applies its layouts and styles to the generated content, and writes the output file. Without a template reference, the skill falls back to generic styling.

## Adding Templates

1. Export the master POTX from PowerPoint (File → Save As → PowerPoint Template `.potx`) with all slide layouts intact.
2. Export the DOTX from Word (File → Save As → Word Template `.dotx`) with styles defined (not just direct formatting).
3. Place both files in this directory.
4. Commit — the templates travel with the repo so all team members get them.

## Updating Templates

Replace the file and commit. The skills always read the template fresh per run, so no cache to clear.
