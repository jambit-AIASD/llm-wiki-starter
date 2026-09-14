---
name: fetch-recording-transcript
description: >
  On-demand: navigate directly to SharePoint, find the most recent recording in
  the channel's Recordings folder, and write its .vtt transcript straight into
  docs/meetings/ — no Teams, no browser download dialog, no Downloads folder.
---

# Fetch Recording Transcript

Retrieve the transcript of the most recent Teams meeting recording for a
channel and save it into `docs/meetings/` in this repo.

## When to use

Invoked on demand, e.g. `/fetch-recording-transcript` or
`/fetch-recording-transcript <channel name>`. There is no automatic schedule —
this only runs when explicitly triggered.

## Argument — channel folder name

The argument is the **name of the channel's folder inside SharePoint Shared
Documents**, e.g. `/fetch-recording-transcript Tech Trends`.

If omitted, default to **`AI Optimierung entlang des SDLCs`**.

The folder name is typically identical to the Teams channel name.

## Tools required

Load these before starting (they may be deferred):

```
ToolSearch("select:mcp__claude-in-chrome__tabs_context_mcp,mcp__claude-in-chrome__navigate,mcp__claude-in-chrome__computer,mcp__claude-in-chrome__tabs_create_mcp,mcp__claude-in-chrome__tabs_close_mcp,mcp__claude-in-chrome__read_network_requests,mcp__claude-in-chrome__javascript_tool")
```

---

## Step-by-step procedure

### 1. Start the local receiver server

```bash
uv run scripts/vtt_receiver.py docs/meetings 8765 &
sleep 1 && echo "Server ready"
```

### 2. Open a tab and query the REST API for the most recent recording

Navigate to the SharePoint site root:

```
https://jambitcom.sharepoint.com/sites/PoC-AIAssistedSoftwareDevelopment
```

Then call the SharePoint REST API to get the most recent `.mp4` filename and
date — no need to read the file list visually:

```javascript
// javascript_tool on that tab:
const siteBase = "https://jambitcom.sharepoint.com/sites/PoC-AIAssistedSoftwareDevelopment";
const channel = "<CHANNEL>";  // e.g. "AI Optimierung entlang des SDLCs"
const folder = `/sites/PoC-AIAssistedSoftwareDevelopment/Shared Documents/${channel}/Recordings`;
const apiUrl = `${siteBase}/_api/web/GetFolderByServerRelativeUrl('${encodeURIComponent(folder)}')/Files?$select=Name,TimeCreated&$orderby=TimeCreated desc&$top=1`;
const data = await fetch(apiUrl, {credentials: 'include', headers: {Accept: 'application/json;odata=verbose'}}).then(r => r.json());
JSON.stringify(data?.d?.results?.[0])
```

This gives you:
- `Name` — the filename (e.g. `Planning AI Optimierung SDLC-20260910_133047UTC-Meeting Recording.mp4`)
- `TimeCreated` — the date

Extract the date from the filename (`20260910` → `2026-09-10`) and slugify the
title for the output filename (e.g. `2026-09-10-planning-ai-optimierung-sdlc.vtt`).

### 3. Navigate to the Recordings folder and click the file

**Important:** Microsoft Stream only initializes its player when opened by a
real SharePoint click. Direct `navigate` calls produce a broken "bypass" player
with no controls. So after getting the filename via REST API, you must still
open the Stream player via a click.

Navigate this same tab to the Recordings folder:

```
https://jambitcom.sharepoint.com/sites/PoC-AIAssistedSoftwareDevelopment/Shared%20Documents/Forms/AllItems.aspx?viewid=b2882e63%2De68f%2D4da7%2Dbd47%2D2d3744b3a0c9&FolderCTID=0x012000D637A550FAAEED4493E0D5B875435A21&id=%2Fsites%2FPoC-AIAssistedSoftwareDevelopment%2FShared%20Documents%2F<CHANNEL_ENCODED>%2FRecordings
```

URL-encode the channel name (spaces → `%20`).

Wait for the file list to load (zoom the content area to confirm). Then click
the most recent `.mp4` row. Since you already know the filename from the REST
API, you just need to click the first row. The click opens a new tab — get its
ID from `tabs_context_mcp`.

Back-calculate click coordinates from zoomed images:
```
x_real = x0 + (x_zoomed / output_width)  × (x1 - x0)
y_real = y0 + (y_zoomed / output_height) × (y1 - y0)
```

After the click, the Recordings folder tab stays open until step 8 — do NOT
close it yet. The extension uses it as the group anchor; closing it first
orphans the Stream tab.

### 4. Enable network monitoring, pause video, open Transcript

On the Stream player tab:

```
read_network_requests(tabId=<stream-tab>, clear=true)
```

Pause the video immediately:

```javascript
// javascript_tool on the Stream player tab:
const v = document.querySelector('video');
if (v) { v.pause(); v.muted = true; }
"paused"
```

Click the Transcript button via JavaScript:

```javascript
// javascript_tool on the Stream player tab:
document.querySelector('button[aria-label="Transcript"]').click();
"clicked"
```

### 5. Capture the transcript URL

```
read_network_requests(tabId=<stream-tab>, urlPattern="transcript", limit=5)
```

Extract `driveId`, `itemId`, and `transcriptkey` from the `cdnmedia/transcripts`
request URL and build the streamContent URL:

```
https://jambitcom.sharepoint.com/sites/PoC-AIAssistedSoftwareDevelopment/_api/v2.1/drives/<driveId>/items/<itemId>/media/transcripts/<transcriptId>/streamContent?is=1&applymediaedits=false
```

### 6. Fetch in-page and POST to local server

```javascript
// javascript_tool on the Stream player tab:
window.__vtt = await fetch('<transcript-url>', {credentials: 'include'}).then(r => r.text());
const filename = '<YYYY-MM-DD-slugified-title>.vtt';
const resp = await fetch(`http://127.0.0.1:8765/${filename}`, {
  method: 'POST',
  headers: {'Content-Type': 'text/plain; charset=utf-8'},
  body: window.__vtt
});
await resp.text()  // should return "OK"
```

### 7. Verify

```bash
ls -lh docs/meetings/<slug>.vtt
```

If a file already exists at that path, report it and ask before replacing.

### 8. Clean up

Close tabs in this order — Stream tab first, then Recordings tab:
```
tabs_close_mcp(tabId=<stream-tab>)
tabs_close_mcp(tabId=<recordings-tab>)
```
The receiver server shuts itself down after one POST.

### 9. Report

Report the destination path and meeting title/date to the user.

---

## Constraints

- **Never open Teams** — go straight to SharePoint.
- **Do not use `navigate` to open the Stream player** — it produces a broken
  "bypass" player. The file must be opened via a click in the SharePoint file
  list (step 3). The Recordings folder tab can be closed immediately after the
  click opens the Stream player tab.
- Never modify or ingest anything outside `docs/meetings/`.
- The receiver server handles one request then exits. Restart it if running the
  skill more than once in a session.
