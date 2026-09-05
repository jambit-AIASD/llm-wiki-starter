# llm-wiki-starter

A general-purpose, domain-agnostic knowledge wiki inspired by Andrej Karpathy's
[LLM Wiki pattern](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f).
Drop source documents into `raw/` — by direct push or by opening a GitHub issue
labeled `wiki-ingest` — and an AI agent curates them into an interlinked wiki
under `wiki/`, which is published as a searchable static site.

---

## How it works

```
raw/            immutable source documents (the inputs)
   │
   ▼   AI curation (Claude, per CLAUDE.md)
wiki/           interlinked knowledge pages
   │
   ▼   build (Quartz)
local site      static HTML, served on demand with `quartz build --serve`
```

- **`raw/`** is append-only. Text files land directly; binaries (PDF, DOCX,
  PPTX, XLSX, HTML) are converted to Markdown first.
- **`wiki/`** is fully owned by the AI agent: one summary page per source
  (`wiki/sources/`), plus entity and concept pages, a catalog (`index.md`),
  an append-only `log.md`, and an evolving `overview.md`.
- Publishing renders `wiki/` with [Quartz](https://quartz.jzhao.xyz/). There is
  no hosted deploy — `wiki-publish.yml` only builds the site as a validation
  checkpoint; you view it by running Quartz locally. No cloud storage or
  hosting account is required anywhere in this pipeline.

See [docs/architecture.md](docs/architecture.md) for the full pipeline, search
index, and toolchain sync details.

> **Fastest way to add content:** open an issue on this repo, label it
> `wiki-ingest`, and either attach a file or paste Markdown as the body. See
> [Add source documents](#3-add-source-documents) below.

---

## Getting started

### 1. Create a new repo from this template

Click **Use this template → Create a new repository** on GitHub to create your
own wiki instance. Set visibility to **Private** — wikis typically contain
internal or proprietary content. Each instance is an independent repo with its
own `raw/` and `wiki/`.

**Domain skills** configure what kind of wiki this is — entity types, concept
types, page structure conventions, and any ingest extensions. Two skills are
included out of the box:

| Skill | Purpose |
|---|---|
| `wiki-curate-default` | General-purpose document wiki (articles, papers, meeting notes, etc.) |
| `wiki-curate-scripts` | Script-continuity wiki — show drafts, numbered-draft evolution, `## Current`/`## History` tracking |

To add a new domain, create `.claude/skills/<your-skill>/SKILL.md` modelled on
one of the existing skills, and set `WIKI_CURATE_SKILL=<your-skill>` in the
repo's Action variables. `CLAUDE.md` covers the universal mechanics; the skill
covers everything domain-specific.

### 2. Configure secrets and variables

**Secrets** (Settings → Secrets → Actions):

| Secret | Purpose |
|---|---|
| `ANTHROPIC_API_KEY` | AI agent (curate, review workflows) |
| `WIKI_PAT` | Cross-workflow Git operations and PRs — create at GitHub → Settings → Developer settings → Personal Access Tokens → Tokens (classic); grant `repo` and `workflow` scopes |

**Variables** (Settings → Variables → Actions):

| Variable | Default | Effect |
|---|---|---|
| `WIKI_CURATE_SKILL` | `wiki-curate-default` | Domain skill the curate workflow loads — see Domain skills above |
| `WIKI_PUBLISH_ENABLED` | — | Allow the curate chain to dispatch the build-validation checkpoint |
| `WIKI_CURATE_CRON_ENABLED` | — | Enable the every-4-hours curate safety-net cron |
| `WIKI_CURATE_BATCH_SIZE` | `5` | Curations to accumulate before the next checkpoint |

### 3. Add source documents

**GitHub Issue** (easiest) — open an issue labeled `wiki-ingest`. Either
drag-and-drop one file into the issue body, or just paste/write Markdown
content directly. Add a `path/<subfolder>` label to route it under
`raw/<subfolder>/...`. No external storage account needed — see
`wiki-ingest-issue.yml`.

**Push directly** (Markdown or assets):

```bash
# Stage files and commit with the required Git trailers
# (the wiki-raw-push skill automates this from Claude Code)
git commit -m "raw: add my-document.md

X-Wiki-Workflow: ingest
X-Raw-Source: raw/my-document.md"
```

> **Local curation in Claude Code:** To curate a raw file yourself without
> waiting for CI, combine the domain skill and file path in one command — e.g.
> `/wiki-curate-default for raw/my-doc.md`. The skill loads entity types, page
> structure conventions, and ingest rules for your domain, and Claude ingests
> immediately. Use the `wiki-push` skill to commit the result with the correct
> git trailers so CI's stale-detection skips it.

**Binary files** (PDF, DOCX, PPTX, XLSX, HTML):
Use the `binary-transform` skill in Claude Code, which converts to Markdown and
places the result in `raw/`.

**Remote dispatch** — send a `repository_dispatch` event with type
`wiki-ingest`, pointing `file_url` at any pre-signed/fetchable URL (works with
any storage provider — S3 presigned URL, GCS signed URL, self-hosted MinIO, etc.):

```json
{
  "event_type": "wiki-ingest",
  "client_payload": {
    "file_url": "https://<storage>/<container>/<guid>-filename.pdf?<sas>",
    "filename": "filename.pdf",
    "subpath": "optional/topic/folder"
  }
}
```

### 4. Watch the pipeline run

A push to `raw/**` triggers `wiki-ingest-push.yml`, which dispatches
`wiki-curate.yml`. The curate workflow runs the AI agent, commits the resulting
`wiki/` changes, and self-re-triggers until all stale files are processed.

---

## Local development

```bash
# Install uv (once)
brew install uv

# Install dependencies
uv sync
```

### View the wiki with Quartz

Quartz reads its content and config relative to the `quartz/` directory, so
link `wiki/` in and copy the config before building — same steps
`wiki-publish.yml` runs in CI:

<details>
<summary>Manual steps</summary>

```bash
npm ci --prefix quartz
rm -rf quartz/content && ln -s ../wiki quartz/content
cp quartz.config.yaml quartz/quartz.config.yaml
cd quartz && npx quartz build --serve
```

</details>

```bash
npm run wiki:install   # once, or after quartz/ dependencies change
npm run wiki:serve     # link wiki/, build, and serve at http://localhost:8080
```

Stop the server with Ctrl+C. Re-run `npm run wiki:serve` any time after
`wiki/` changes — it also watches and rebuilds automatically while running.

### Rebuild the qmd search index

```bash
npm run index   # bash scripts/setup-dev.sh — qmd init/update/embed
```

### Convert between Markdown and Office / PDF formats

Claude Code skills convert in both directions — binary files to Markdown for
ingest into `raw/`, and Markdown (or wiki content) back to a formatted document
using a template. Run any skill with `/` in an interactive Claude Code session:

| Skill | To Markdown | From Markdown |
|---|---|---|
| `/pdf` | Extract text and images from a PDF | — |
| `/pptx` | Extract slide content to Markdown | Generate a `.pptx` from wiki content + template |
| `/docx` | Extract a Word document to Markdown | Generate a `.docx` from wiki content + template |
| `/xlsx` | Extract spreadsheet tables to Markdown | — |

See [README_DOC_TOOLS.md](README_DOC_TOOLS.md) for full usage, template support,
and the `binary-transform` skill that writes converted files directly into `raw/`.

---

## Workflows

| Workflow | Trigger | Purpose |
|---|---|---|
| `wiki-ingest-push.yml` | push to `raw/**` | Detects stale files, kicks off curate chain |
| `wiki-ingest.yml` | `repository_dispatch` | Stages a remote file (any URL) into `raw/` |
| `wiki-ingest-issue.yml` | issue labeled `wiki-ingest` | Stages an issue's attachment/body into `raw/` |
| `wiki-curate.yml` | workflow_dispatch / cron | Runs AI agent on one stale file; self-chains |
| `wiki-review.yml` | PR label / approval | Re-lints and auto-merges conflict PRs |
| `wiki-publish.yml` | dispatch from curate | Builds Quartz as a validation checkpoint (no deploy) |
| `wiki-reset.yml` | manual (`confirm=yes-reset`) | Wipes `wiki/`, restarts curate chain |
| `wiki-sync.yml` | manual | Syncs toolchain updates to instance repos |

---

## Repository layout

```
raw/                        Source documents (never modified after ingest)
raw/assets/                 Binary assets referenced by raw sources
wiki/                       AI-curated knowledge pages
wiki/sources/               One summary page per ingested source
wiki/entities/              People, organizations, products, places (generic default)
wiki/concepts/              Ideas, frameworks, terms, techniques (generic default)
wiki/assets/raw/            Assets served to the site (mirrors raw/assets/)
docs/architecture.md        Full architecture reference
scripts/                    Dev/CI helpers
.claude/skills/wiki-curate-default/   General-purpose domain skill
.claude/skills/wiki-curate-scripts/   Script-continuity domain skill
.github/workflows/          CI/CD automation
```

---

## Based on

Implements the [LLM Wiki pattern](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f)
by Andrej Karpathy: immutable raw sources, an AI-maintained wiki layer that compounds over time,
and a governing schema (`CLAUDE.md`) that defines how the agent ingests, queries, and lints.
The three operations (INGEST / QUERY / LINT), `index.md`, `log.md`, and contradiction flagging
are all direct implementations of that pattern.

---

## License

MIT
