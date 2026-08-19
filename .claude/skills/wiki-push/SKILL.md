---
name: wiki-push
description: >
  Stage manually curated wiki/ files, commit with the required
  X-Wiki-Workflow: curate and X-Raw-Source: trailers, and push to origin main
  so wiki-curate's stale-detection skips the corresponding raw files in the
  next cycle. Also handles locally created raw/ files that have not yet been
  ingested — commits them first with X-Wiki-Workflow: ingest trailers so the
  full ingest→curate lineage is recorded in one push.
---

# Wiki Push

Commit and push manually created or modified `wiki/` files with the correct Git
trailers so `wiki-curate.yml`'s stale-detection registers them as already
curated. When the corresponding `raw/` source files are also new locally (not
yet in any ingest commit), commits them first with ingest trailers so the
complete lineage is recorded — matching exactly what the CI pipeline would have
produced.

## When to use

- **Wiki-only push:** You wrote or edited files under `wiki/` for raw files that
  were already ingested via CI — a manual curation session, a stub-ingest batch.
- **Local end-to-end push:** You created a new `raw/` file locally, curated it
  into `wiki/` without going through CI, and want to push both layers together
  with the correct trailer chain.

## How it works

`wiki-curate.yml`'s stale-detection uses two separate `git log --all-match`
checks per raw file:

- **Ingest:** any commit with `X-Wiki-Workflow: ingest` AND `X-Raw-Source: <F>` —
  searched across all history (not reset-scoped).
- **Curate:** any commit with `X-Wiki-Workflow: curate` AND `X-Raw-Source: <F>` —
  searched only since the last `X-Wiki-Workflow: reset` commit.

A file is stale when `LAST_CURATE` is empty OR `LAST_INGEST > LAST_CURATE`. A
curate commit alone is sufficient to prevent re-curation in the current cycle,
but without an ingest commit a reset would re-expose the file. This skill
always produces both commits when the raw file is locally new, exactly mirroring
what CI would have produced.

**Commit order:** the ingest commit(s) are made before the curate commit so
timestamps are chronologically ordered (ingest < curate) — matching CI behaviour.

## Optional argument

You may be invoked with a file list: `/wiki-push file-a.md file-b.md …`

Each item is matched against the `git status` output:
- If the item contains `/`, match it as a repo-relative path (exact).
- Otherwise match against basenames only.
- If a bare filename matches more than one entry in the status list, report the
  ambiguity and the full paths of all matches, then stop — do not guess.
- If any item in the list matches nothing in the status list, warn and skip it.

When a file list is supplied, only the named wiki/ files are staged; other wiki/
files in `git status` are left untouched. Any raw/ files that are locally new
and correspond to the named wiki/sources pages are still committed (ingest
commits), because they are a precondition for the curate commit to be valid.

## Procedure

1. **Pre-flight: check remote is reachable and local is not behind** — run:
   ```
   git fetch origin
   git rev-list --count HEAD..origin/main
   ```
   If the count is greater than 0, `origin/main` has commits your local
   history does not. Report this and tell the user to pull/rebase before
   proceeding — do not continue.

2. **Find wiki/ files to commit** — run:
   ```
   git status --short -- 'wiki/**'
   ```
   Collect all lines with status `?? `, `A `, ` M`, or `M ` whose path starts
   with `wiki/`. Exclude `wiki/assets/` (binary assets are not committed here).

   If a file list argument was supplied, filter to the named files using the
   matching rules above. If after filtering the set is empty, report "No
   matching wiki/ files found in git status." and stop.

   If no argument was supplied and no files are found, report "No new or
   modified wiki/ files found." and stop.

3. **Extract raw_file: values** — for every file found in step 2 whose path
   matches `wiki/sources/*.md`:
   - Read the file's YAML frontmatter (between the opening and closing `---`
     delimiters).
   - Extract the value of the `raw_file:` key, stripping surrounding quotes
     if present.
   - Collect these values into an ordered list, deduplicating by value.
   - If a `wiki/sources/` file has **no** `raw_file:` key in its frontmatter,
     warn the user ("warning: <file> has no raw_file: — it will be staged but
     will not generate an X-Raw-Source trailer") and continue.

   Non-source wiki files (`wiki/index.md`, `wiki/log.md`, `wiki/overview.md`,
   `wiki/entities/`, `wiki/concepts/`) generate no `X-Raw-Source:` entries on
   their own — they are bundled into the curate commit as supporting output.

4. **Detect uningested raw/ files** — for each `raw_file:` value collected in
   step 3:

   a. **Is the file locally new or modified?** Run:
      ```
      git status --short -- '<raw_file_path>'
      ```
      If the status is `?? `, `A `, ` M`, or `M `, the file is locally new or
      modified and not yet committed — it needs an ingest commit.

   b. **Has any ingest commit been recorded?** Even if the file is already
      committed, check whether an ingest commit exists:
      ```
      git log --format='%H' \
        --grep='X-Wiki-Workflow: ingest' \
        --grep='X-Raw-Source: <raw_file_path>' \
        --all-match | head -1
      ```
      If the output is empty AND the file is already committed (not caught by
      check (a)), warn: "warning: <raw_file_path> is committed but has no
      ingest record — after a wiki-reset it would appear stale again. Consider
      running wiki-raw-push for this file separately." Do not block on this.

   c. **Check for asset dependencies** — scan the raw file for image embeds
      and links containing `/assets/`:
      ```
      grep -oE '\]\([^)]+\)' '<raw_file_path>' | grep '/assets/'
      ```
      If any are found, check whether the referenced asset paths exist under
      `raw/assets/` and whether they appear in `git status` (new/modified).
      If assets are new and unstaged, warn the user: "warning: <raw_file_path>
      references assets that are not yet committed. Wiki-curate reads the raw
      file at the commit tree, so missing assets will produce broken links.
      Consider using wiki-raw-push for this file instead, which handles asset
      co-staging." Do not block, but make the risk clear.

   Build a list: **uningested raw files** — those caught by check (a) (locally
   new/modified, status `??`/`A `/` M`/`M `).

5. **Show the plan** to the user before making any changes. The plan has two
   sections:

   **A. Ingest commits** (one per uningested raw/ file, in the order they were
   found in step 4):
   ```
   raw: ingest <basename>

   X-Wiki-Workflow: ingest
   X-Raw-Source: <raw_file_path>
   ```
   List each raw file that will be committed with its ingest trailer, plus any
   asset files that ride along in the same commit.

   If no uningested raw files were found, note: "No uningested raw/ files
   detected — skipping ingest commits."

   **B. Curate commit** (one batch for all wiki/ files):
   ```
   wiki: curate <N> raw file(s)

   X-Wiki-Workflow: curate
   X-Raw-Source: <raw_file_1>
   X-Raw-Source: <raw_file_2>
   ...
   ```
   List every wiki/ file that will be staged.

   If step 3 produced **zero** `X-Raw-Source:` entries (no source pages in the
   change set), warn the user — a commit without `X-Raw-Source:` trailers marks
   no file as curated, which may be intentional (housekeeping) but is unusual.

   **Stop here and wait for explicit confirmation before proceeding.**

6. **Commit uningested raw/ files** — for each file in the uningested list from
   step 4, in order, one commit per file (matching wiki-raw-push format):
   ```
   git add <raw_file> [<asset_file_1> ...]
   git commit \
     -m "raw: ingest <basename>" \
     -m "" \
     -m "X-Wiki-Workflow: ingest
   X-Raw-Source: <raw_file_path>"
   ```
   Include any new/modified asset files that the raw file references (from
   check (c) in step 4). Only the markdown file gets an `X-Raw-Source:` trailer;
   assets ride along without one.

   Skip this entire step if the uningested list is empty.

7. **Stage and commit wiki/ files** — stage every file from step 2, then commit
   using the same format `wiki-curate.yml` produces:
   ```
   git add <wiki-file-1> <wiki-file-2> ...
   git commit \
     -m "wiki: curate <N> raw file(s)" \
     -m "" \
     -m "X-Wiki-Workflow: curate
   X-Raw-Source: <raw_file_1>
   X-Raw-Source: <raw_file_2>
   ..."
   ```
   `<N>` is the count of unique `raw_file:` values from step 3.

8. **Push all commits at once**:
   ```
   git push origin HEAD:main
   ```
   If the push is rejected, report the error and tell the user to
   pull/rebase first — do not force-push.

9. **Report** — list the commits made (ingest commit(s) if any, then curate
   commit), the files in each, and confirm the push succeeded. Mention that the
   next `wiki-curate.yml` run will skip all declared raw files as already
   curated, and (if ingest commits were made) that the full ingest→curate
   lineage is now recorded and will survive a wiki-reset.

## Constraints

- Stage raw/ files only in ingest commits (step 6); stage wiki/ files only in
  the curate commit (step 7). Never mix raw/ and wiki/ in a single commit.
- Only stage wiki/ files under `wiki/` and raw/ files under `raw/`. For raw/
  files with significant asset dependencies, prefer wiki-raw-push (which has
  full asset-resolution logic) and then use wiki-push for the wiki/ layer only.
- Never commit `wiki/assets/` binary files directly. Those are copied by CI
  (`rsync raw/assets/ → wiki/assets/raw/`) before Claude runs; pushing them
  manually would duplicate what CI manages.
- The `raw_file:` value in each source page's frontmatter **must** exactly
  match the path of the raw file on disk. If a value looks wrong (path does not
  exist), warn the user before committing.
- Ingest commit(s) must be made **before** the curate commit (step 6 before
  step 7) so timestamps are ordered correctly for stale-detection.
- Never force-push. Never amend an existing commit.
