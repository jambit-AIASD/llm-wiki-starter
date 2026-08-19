---
name: wiki-raw-push
description: >
  Stage new or modified raw/ markdown files, commit with the required
  X-Wiki-Workflow: ingest and X-Raw-Source: trailers, and push to origin main
  so wiki-curate picks them up automatically.
---

# Wiki Raw Push

Commit and push new or modified `raw/` markdown files with the correct Git
trailers so `wiki-curate.yml` detects them as stale and processes them.

## When to use

You have added or edited one or more `.md` files under `raw/` directly (not
via the Logic App / wiki-ingest workflow) and want wiki-curate to pick them up.

## Optional argument

You may be invoked with a file list: `/wiki-raw-push file-a.md file-b.md …`

Each item is matched against the `git status` output:
- If the item contains `/`, match it as a repo-relative path (exact).
- Otherwise match against basenames only.
- If a bare filename matches more than one entry in the status list, report the
  ambiguity and the full paths of all matches, then stop — do not guess.
- If any item in the list matches nothing in the status list, warn and skip it.

Only the matched subset is processed. Files in the status list that were not
named are left untouched.

## Procedure

1. **Pre-flight: check remote is reachable and local is not behind** — run:
   ```
   git fetch origin
   git rev-list --count HEAD..origin/main
   ```
   If the count is greater than 0, `origin/main` has commits your local
   history does not. Report this and tell the user to pull/rebase before
   proceeding — do not continue.

2. **Find markdown files to commit** — run:
   ```
   git status --short -- 'raw/**/*.md'
   ```
   Collect all lines with status `?? `, `A `, ` M`, or `M ` whose path:
   - starts with `raw/`
   - ends with `.md`
   - does NOT start with `raw/assets/`

   If a file list argument was supplied, filter this set to only the named
   files using the matching rules above. If after filtering the set is empty,
   report "No matching raw/ markdown files found in git status." and stop.

   If no argument was supplied and no files are found, report "No new or
   modified raw/ markdown files found." and stop.

3. **Resolve each file's asset dependencies** — for every markdown file found:
   - Extract link/image targets: `grep -oE '\]\([^)]+\)' <file>`.
   - Drop `http://`, `https://`, and `mailto:` targets.
   - URL-decode the remainder (e.g. `%20` → space).
   - Resolve each target relative to the markdown file's own directory to get
     a repo-relative path (e.g. via `uv run python3 -c "import os,sys; print(os.path.normpath(os.path.join(os.path.dirname(sys.argv[1]), sys.argv[2])))" <file> <target>`).
   - Keep only resolved paths that fall under `raw/assets/`.
   - For each kept path, check `git status --short -- <path>`. If it's new or
     modified (`??`, `A `, ` M`, `M `), it belongs to this markdown file's commit.
   - If a resolved asset path doesn't exist on disk at all, warn the user
     (broken link in the source) but don't block on it.

4. **Show the list** to the user — each markdown file together with the asset
   files it will bring along — and confirm before proceeding. If a file list
   argument was supplied, include a note that all other markdown files found
   in the status list will remain unstaged.

5. **Check for orphaned assets** — skip this step entirely if a file list
   argument was supplied; those assets belong to the other markdown files and
   will stay unstaged. Otherwise run `git status --short -- 'raw/assets/'`:
   any new/modified asset not claimed by step 2 is orphaned (not referenced
   by any source being pushed). Report these separately; do not silently
   commit or drop them — ask the user how to handle them.

6. **Commit each markdown file together with its resolved assets** — for
   every file from step 1, in one commit:
   ```
   git add <md-file> <asset-1> <asset-2> ...
   git commit \
     -m "raw: ingest <basename>" \
     -m "" \
     -m "X-Wiki-Workflow: ingest
   X-Raw-Source: <md-file>"
   ```
   The blank `-m ""` separates the subject from the trailer block.
   Both trailers must appear in the same commit message body. Only the
   markdown file gets an `X-Raw-Source:` trailer — its assets ride along in
   the same tree without one.

7. **Push all commits at once**:
   ```
   git push origin HEAD:main
   ```
   If the push is rejected, report the error and tell the user to
   pull/rebase first — do not force-push.

8. **Report** the files and assets committed and confirm the push succeeded.
   Mention that wiki-curate will trigger automatically via the `raw/**` push
   event.

## Constraints

- Only stage files under `raw/` (never `wiki/` or anything else).
- Never commit a markdown source without the asset files it references — curate
  reads the source at that commit's tree, so an image pushed in a later commit
  leaves a permanently broken link in the curated wiki page. This is why
  `raw/assets/` lives inside `raw/` in the first place.
- Asset files themselves never get an `X-Raw-Source:` trailer — only `.md`
  sources do; stale-detection keys off that path.
- Never force-push.
- Never amend an existing commit.
