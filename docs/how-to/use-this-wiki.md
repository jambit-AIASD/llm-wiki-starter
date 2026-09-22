# How to use this wiki

This guide explains the thinking behind the system and walks you through
everything you need to get a working wiki — from first setup to day-to-day use.

---

## Why this exists

Knowledge work produces documents faster than anyone reads them. Reports, meeting
notes, research papers, slide decks — they pile up in drives and inboxes where
they are searched once (maybe) and then forgotten.

This repo turns that pile into a living knowledge base. You drop source documents
into `raw/`. An AI agent (Claude, governed by `CLAUDE.md`) reads each one and
synthesises it into an interlinked wiki under `wiki/`: one summary page per
source, plus entity and concept pages that accumulate claims, cross-references,
and contradiction flags over time. Every new source is reconciled against what
is already known, not just appended.

The result is a wiki that *compounds*. The tenth document on the same topic makes
the entity pages richer — not just longer. A claim that appeared in an earlier
source and is contradicted or withdrawn by a later one is flagged in place, with
provenance, rather than silently overwritten.

---

## Mental model

```
raw/        ← what you put in. Append-only. Never touched after ingest.
   │
   ▼   AI curation (Claude, per CLAUDE.md)
wiki/       ← what the agent produces. Sources, entities, concepts, synthesis.
   │
   ▼   Quartz build
site        ← browse the wiki locally as a static site.
```

You own `raw/`. The agent owns `wiki/`. You configure what kind of wiki this is
via a *domain skill* (see [Domain skills](#domain-skills) below).

---

## First-time setup

### 1. Create your repo from the template

On GitHub: **Use this template → Create a new repository**.

Set visibility to **Private** — wikis typically contain internal content.

Clone your new repo locally:

```bash
git clone https://github.com/<you>/<your-wiki>.git
cd <your-wiki>
```

### 2. Configure secrets and variables

In your repo: **Settings → Secrets and variables → Actions**.

**Secrets** (required):

| Secret | What it's for |
|---|---|
| `ANTHROPIC_API_KEY` | The AI agent that curates your documents |
| `WIKI_PAT` | A Personal Access Token for cross-workflow Git operations — create at GitHub → Developer settings → Personal Access Tokens (classic); grant `repo` and `workflow` scopes |

**Variables** (optional defaults shown):

| Variable | Default | What it controls |
|---|---|---|
| `WIKI_CURATE_SKILL` | `wiki-curate-default` | Which domain skill the agent loads — see below |
| `WIKI_PUBLISH_ENABLED` | *(unset)* | Set to any non-empty value to enable build-validation after each curation chain |
| `WIKI_CURATE_CRON_ENABLED` | *(unset)* | Set to enable a safety-net cron that re-checks for stale files every 4 hours |
| `WIKI_CURATE_BATCH_SIZE` | `5` | Curations to accumulate before the next build checkpoint |

### 3. Install local dependencies

```bash
brew install uv            # Python package manager (once)
uv sync                    # install Python deps (needed for binary conversion)
npm run wiki:install       # install Quartz (static site generator)
```

---

## Domain skills

A *domain skill* tells the agent what kind of wiki this is: what counts as an
entity versus a concept, how to structure pages, and what ingest rules to apply.

Two skills ship out of the box:

| Skill | Use when your documents are… |
|---|---|
| `wiki-curate-default` | General-purpose: articles, papers, reports, meeting notes, research |
| `wiki-curate-scripts` | Show scripts, screenplays, or numbered draft series — tracks characters, running bits, and draft evolution |

To select a skill, set `WIKI_CURATE_SKILL` in your repo's Action variables (see
step 2). The default is `wiki-curate-default`.

To create a new domain: copy `.claude/skills/wiki-curate-default/` to
`.claude/skills/<your-skill>/`, edit `SKILL.md` to define your entity types,
concept types, and any ingest extensions, then set `WIKI_CURATE_SKILL=<your-skill>`.

---

## Adding documents

### Option A — GitHub Issue (simplest, no local setup)

1. Open a new issue on your repo.
2. Label it `wiki-ingest`.
3. Either drag a file into the issue body, or paste Markdown content directly.
4. Optionally add a `path/<subfolder>` label to organise the file under
   `raw/<subfolder>/`.
5. Submit the issue. The workflow picks it up, stages the file into `raw/`, and
   kicks off curation. The issue is closed with a comment when done.

This works for any text, Markdown, or single binary attachment. No storage
account or external tooling required.

### Option B — Direct push (Markdown files)

Commit your Markdown source with two required Git trailers so the pipeline
recognises it as an ingest:

```bash
git add raw/my-topic/my-document.md
git commit -m "raw: add my-document.md

X-Wiki-Workflow: ingest
X-Raw-Source: raw/my-topic/my-document.md"
git push
```

The push triggers `wiki-ingest-push.yml`, which finds the new stale file and
dispatches the curation agent.

The `wiki-raw-push` skill in Claude Code automates this — run
`/wiki-raw-push` and it stages, commits with the correct trailers, and pushes.

### Option C — Binary files (PDF, DOCX, PPTX, XLSX)

Binaries must be converted to Markdown before ingest. In an interactive Claude
Code session:

```
/binary-transform
```

or use the format-specific skills directly:

```
/pdf           # extract text and images from a PDF
/docx          # extract a Word document
/pptx          # extract slide content
/xlsx          # extract spreadsheet tables
```

Place your binary in `import/` (gitignored). The skill converts it to Markdown
in `raw/` and records the conversion in `ingest-manifest.jsonl`. Then push with
the trailers as in Option B, or run `/wiki-raw-push`.

### Option D — Remote dispatch

Send a `repository_dispatch` event from any system that can make a POST request
to the GitHub API:

```json
{
  "event_type": "wiki-ingest",
  "client_payload": {
    "file_url": "https://<storage>/<container>/<file>?<token>",
    "filename": "filename.pdf",
    "subpath": "optional/topic/folder"
  }
}
```

`file_url` can be any fetchable URL — a presigned S3 URL, a GCS signed URL,
a self-hosted MinIO link. The workflow downloads the file, converts binaries to
Markdown, stages the result in `raw/`, and starts curation.

---

## Watching the pipeline

After any ingest (push, issue, or dispatch), the pipeline runs automatically:

1. `wiki-ingest-push.yml` detects the new stale file and dispatches the curate job.
2. `wiki-curate.yml` runs the AI agent on one stale file, commits `wiki/` changes,
   then self-re-triggers until the backlog is empty.
3. If `WIKI_PUBLISH_ENABLED` is set, `wiki-publish.yml` builds Quartz as a
   validation checkpoint when the chain finishes.

Track progress in **Actions** → select a run to see the agent's commits flowing in.

If a commit conflicts with an in-flight change, the workflow opens a PR tagged
`needs-review` rather than force-pushing. Remove the label (or approve the PR)
to let `wiki-review.yml` re-lint and auto-merge.

---

## Browsing the wiki locally

```bash
npm run wiki:serve
```

This links `wiki/` into Quartz, builds the static site, and serves it at
`http://localhost:8080`. It also watches for changes and rebuilds automatically.

Stop with Ctrl+C. Re-run any time after the pipeline commits new wiki pages.

---

## Curating locally (without CI)

You can run the full curation workflow yourself in an interactive Claude Code
session — useful for immediate feedback or for reviewing the agent's output
before it lands on `main`.

Combine the domain skill with the file path in one command:

```
/wiki-curate-default for raw/my-topic/my-document.md
```

or for the scripts domain:

```
/wiki-curate-scripts for raw/scripts/Draft05.md
```

The skill loads your domain rules and Claude ingests the file immediately —
creating or updating all affected wiki pages, updating `index.md`, and appending
to `log.md`. When you're satisfied, commit and push the result with
`/wiki-push` (which uses the correct trailers so CI's stale-detection skips it).

---

## Querying the wiki

From a Claude Code session, ask questions in plain English:

```
Query: What did the Q3 report say about the migration timeline?
```

Claude searches the local qmd index (a SQLite database of `wiki/`), reads the
top-matching pages, and synthesises an answer with inline citations. It then
asks whether to file the answer as a new wiki page — useful for capturing
cross-source syntheses that aren't already in any single source page.

To rebuild the search index after adding new pages:

```bash
npm run index
```

---

## Health-checking the wiki

Run a lint pass to catch structural problems:

```
Lint the wiki
```

Claude checks for orphaned pages, broken links, missing `## See Also` sections,
stale `source_count` values, contradictions that haven't been resolved, and
claims still stated as current that a later source has withdrawn. It reports
findings and suggests new sources or questions to investigate.

In CI, `wiki-review.yml` runs an automated lint on PR diffs and sets
`safe: true/false` — a `false` result blocks the merge until the issue is fixed.

---

## Resetting the wiki

If you want to start the wiki layer over from scratch (raw sources unchanged):

1. Go to **Actions → wiki-reset → Run workflow**.
2. Enter `yes-reset` in the confirmation field.

This wipes `wiki/` pages back to stubs, drops build tags, and restarts the
curation chain so every raw file is re-curated from scratch. Use it when you've
changed your domain skill significantly and want the whole wiki regenerated
under the new rules.

---

## Tips and common questions

**Do I have to wait for CI?** No — use `/wiki-curate-default` (or your domain
skill) in Claude Code to curate immediately. CI is the unattended path.

**Can I edit wiki pages by hand?** Yes. The agent will incorporate your edits
on the next ingest of a related source. Just don't edit `raw/` — that's the
immutable source layer.

**How do I organise raw files into topics?** Use subfolders freely:
`raw/research/`, `raw/meetings/2026/`, etc. The pipeline discovers any file
anywhere under `raw/**`. Add a `path/<subfolder>` label on an issue to route
issue attachments into a specific subfolder.

**What happens when a new source contradicts an older one?** The agent flags the
contradiction in place with a `⚠️ Contradiction noted:` blockquote on the
affected page, adds the new claim with provenance, and logs it in `wiki/log.md`.
It does not silently overwrite.

**Can I host the site publicly?** `wiki-publish.yml` is a build-validation
checkpoint only — it doesn't deploy anywhere. To host publicly, point a static
site host (GitHub Pages, Netlify, Cloudflare Pages, etc.) at the built Quartz
output. See the [Quartz documentation](https://quartz.jzhao.xyz/hosting) for
hosting options.

**The pipeline is stuck / nothing is curating.** Check:
- Actions tab for a failed run and its error log.
- That `ANTHROPIC_API_KEY` and `WIKI_PAT` are set correctly.
- Whether a `needs-review` PR is blocking the chain.
- Run `wiki-curate.yml` manually (workflow_dispatch) to force a single curation pass.

---

## See also

- [README.md](../README.md) — quick-start overview
- [docs/architecture.md](architecture.md) — full pipeline, search index, and toolchain sync
- [CLAUDE.md](../CLAUDE.md) — the AI agent's operating contract (page conventions, ingest/lint workflows)
