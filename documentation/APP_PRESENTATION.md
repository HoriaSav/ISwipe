# ISwipe — App Presentation

> **Living document.** Describes what ISwipe is and how every part of the app behaves.  
> Update this file whenever features, flows, or UX change. Last updated: **2026-08-30**.

---

## What ISwipe is

**ISwipe** is a local-only photo triage app for **Android** and **iOS**. It helps you clean and organize your camera roll by swiping through photos — keep, delete, defer, or favorite — without creating an account or uploading anything to the cloud.

The core idea: open the app, see one photo at a time, make a quick decision with a gesture, and move on. For repetitive cleanup (duplicates, screenshots, large files), ISwipe surfaces smart queues so you spend time on decisions that matter.

| Promise | Detail |
|---------|--------|
| **Private** | All scanning, decisions, and analytics stay on your device |
| **Safe deletes** | Nothing goes to OS trash until you review and confirm |
| **Resumable** | Pick up album sorting where you left off |
| **Fast triage** | Home screen highlights what is worth cleaning first |

---

## How you move through the app

```
┌─────────────────────────────────────────────────────────────┐
│  App bar: tab title                    [Settings ⚙]         │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│   Tab content (Home / Gallery / Deleted / Analytics)        │
│                                                             │
├─────────────────────────────────────────────────────────────┤
│  [ Home ]  [ Gallery ]  [ Deleted ]  [ Analytics ]          │
└─────────────────────────────────────────────────────────────┘
```

- **Bottom tabs**: Home, Gallery, Deleted, Analytics.
- **Settings** is always available from the app bar on main tabs and in folder view.
- **Settings is hidden** while you are in swipe sort mode (full-screen focus).
- Tab icons use an outlined style when inactive and filled when selected.
- Switching tabs keeps each tab’s state (they do not reload from scratch every time).
- Returning to a tab triggers a silent refresh so counts and thumbnails stay current.

Page transitions use a subtle fade animation.

---

## Home tab

The Home tab is the primary entry point after launch.

### Greeting and library summary

- Shows a time-based greeting (Good morning / afternoon / evening).
- Displays an approximate **photo count** for your library (from the primary system album).
- Privacy tagline reinforces that analysis happens on-device.

### Library scan

ISwipe does **not** auto-scan your entire library on every launch (that was too slow on large libraries).

| Action | Behavior |
|--------|----------|
| **Scan library** button | Starts a full on-device triage scan with a progress bar |
| **Pull to refresh** | Runs the same scan and refreshes cached results |
| No scan yet | Empty state explains you need to scan first |

**What the scan does** (all on-device):

1. Walks photos in pages from the primary album.
2. Classifies **screenshots** (album name, filename heuristics, iOS subtype).
3. Buckets photos by **dimensions**, then reads file size only for likely duplicate candidates.
4. Computes a **thumbnail hash** for duplicate candidates and groups exact matches.
5. Flags **large files** (≥ 5 MB) in a separate pass.
6. Saves results to a local cache so opening categories is instant next time.

### Potential cleanup

After a scan, up to three cleanup categories appear:

| Category | What it contains | How you open it |
|----------|------------------|-----------------|
| **Duplicates** | Groups of identical copies | Duplicate groups screen |
| **Screenshots** | Detected screenshot images | Paginated category gallery |
| **Large files** | Photos ≥ 5 MB, sorted by size | Paginated category gallery |

Each card shows a count (duplicate groups or photo count) and estimated recoverable storage.

### Start Smart Cleanup

One-tap entry into the “best” cleanup opportunity:

1. If no scan results exist, runs a scan first (button shows loading).
2. Picks the category with the highest count (duplicate **groups** count for Duplicates).
3. Opens that category directly.
4. Shows a message if there is nothing to clean.

Helper text under the button explains this behavior.

### Continue

Lists every **album folder that is not fully sorted** (same rule as Gallery → To sort).

- Shows folder name and review progress (`reviewed / total · %`).
- Folders you have already opened appear first (by recent session activity), then the rest.
- Tap a folder to open swipe mode — resumes an existing session when one exists, otherwise starts at the beginning.
- Hidden when every folder is fully sorted.

### Browse folders

Switches to the **Gallery** tab to browse and sort albums manually.

---

## Gallery tab

Shows all image albums/folders the device exposes through the photo library API.

### Folder grid

- **3-column grid** of folder cards.
- Each card: cover thumbnail + album name below.
- Empty albums are filtered out.
- **To sort** folders (not fully reviewed) appear at the top.
- **Sorted** folders (every photo marked reviewed/kept) appear at the bottom, separated by a labeled divider when both sections exist.
- Pull to refresh clears caches and reloads albums.
- Background refresh when returning to the tab (debounced, no full-screen flash after first load).

### Folder view (inside an album)

- **3-column photo grid** — standard gallery browsing.
- Tap any photo to enter **swipe sort mode** at that photo’s position.
- Photos you previously marked **kept/reviewed** show a **green circle with checkmark** in the top-right corner.
- Settings button remains in the app bar.

### Starting a session

When you open swipe mode from a folder, ISwipe creates or resumes an **album session** tied to that folder. Progress is saved as you go.

---

## Swipe sort mode

Full-screen, Tinder-style photo sorting. This is the heart of the app.

### Layout

```
┌──────────────────────────────────────────┐
│  ← Session title              History ⏱  │
│  ████████░░░░  progress bar              │
│  [thumb][thumb][CURRENT][thumb][thumb]   │  ← preview bar (5 past + current + 5 future)
│                                          │
│         ┌────────────────────┐           │
│         │                    │           │
│         │    Large photo     │           │
│         │                    │           │
│         └────────────────────┘           │
│   Delete ←                    → Keep     │  ← labels appear while dragging
│                                          │
│      [Later]    [Undo]    [Favorite]     │
│                                          │
│              [ Close ]                   │
└──────────────────────────────────────────┘
```

### Primary gestures

| Gesture | Action | Immediate effect |
|---------|--------|------------------|
| **Swipe left** | Delete | Photo is **queued** for deletion (not trashed yet) |
| **Swipe right** | Keep | Photo marked reviewed/kept in local database |

After either gesture, the photo **leaves the deck** and the next one appears. You will not see the same kept photo again in the same session.

### Secondary actions (buttons)

| Button | Action |
|--------|--------|
| **Later** | Saves photo to a “decide later” list; removes from current deck |
| **Favorite** | Marks photo as favorite locally; removes from current deck |
| **Undo** | Restores the **last queued delete** and jumps back to that photo |
| **History** (app bar) | Opens session decision log — undo **any** past decision in this session |
| **Close** | Exits swipe mode; if deletes are queued, opens the review screen first |

### Preview bar

Shows up to **5 thumbnails before** the current photo, the **current** photo (highlighted), and up to **5 upcoming** photos. Helps orient you in long albums.

### Progress bar

When a session is active, a bar at the top reflects session progress (`current_index / total_count`).

### Pagination

Large albums and category queues load photos in **pages** (not all at once):

- Album mode: loads next page from the folder when you approach the end of the loaded deck.
- Category/duplicate mode: loads from a fixed ID queue in batches.
- Duplicate groups and cleanup categories pass a predefined asset queue so pagination stays consistent.

### Pending delete banner

While sorting, a banner shows how many photos are queued (e.g. “3 photos queued — review when you close”). Deletes are **not** sent to the system until you confirm on the review screen.

---

## Review commit screen (Stage 2 safety)

When you close swipe mode with queued deletes, you see a **Review deletes** screen before anything reaches the OS trash.

| Element | Behavior |
|---------|----------|
| Summary card | Count of photos + total storage recoverable |
| List | Each queued photo with thumbnail; swipe or tap to remove from queue |
| **Move to trash** | Sends all remaining items to **system trash** in one batch |
| Cancel / back | Returns to swipe mode; queued items stay queued |
| User cancels OS dialog | Photos are kept; app restores UI state |

This is the second stage of the three-stage safety model:

1. **Queue** during swipe (reversible instantly)
2. **Review** on this screen (remove mistakes)
3. **OS trash** (~30 day expiry per platform rules)

---

## Duplicates flow

Duplicates are handled differently from Screenshots and Large files because you need to **compare copies side by side**.

### Duplicate groups screen

- Lists each duplicate **group** (2+ identical photos).
- Top explainer: identical copies often share the **same filename** — that is normal.
- Each group shows up to **3 thumbnails** with:
  - **Copy N** badge
  - Filename
  - Date and file size
  - Folder path (Android `relativePath`; iOS may show parent folder from file path)

### Tapping a copy

Each copy is **individually tappable**:

- Tap **Copy 1** → swipe mode opens on the first copy.
- Tap **Copy 2** → swipe mode opens on the second copy (so you can delete it immediately without swiping past Copy 1 first).

Groups with more than 3 copies show a **+N more** control that opens the group from the start.

### In swipe mode (duplicate group)

Same swipe rules apply: keep one copy, queue the rest for delete, then review and commit.

When you return to the groups list, deleted copies are removed automatically. Groups with only one photo left disappear (no longer duplicates). Home scan counts update from the reconciled cache.

---

## Category gallery (Screenshots & Large files)

Opens a paginated grid (60 photos per batch) instead of loading the entire category at once.

- Scroll near the bottom to load more.
- Tap a photo to enter swipe mode with the full category queue.
- File size may be shown for large files.

---

## Deleted tab

A visual history of photos you have sent to trash through ISwipe.

- **4-column grid** of thumbnail images only — no titles, dates, or album names.
- Thumbnails are saved locally **before** trash (trashed assets are often unreadable from the gallery API).
- Pull to refresh reloads the grid.
- Updates automatically when new deletes are committed or undone.
- Older deletes from before thumbnail support may show empty cells.

This tab is a **reference gallery**, not a file manager — files live in the OS trash.

---

## Analytics tab

Tracks cleanup activity from local deletion records.

### Summary cards

| Period | Metrics |
|--------|---------|
| Today / This month / This year / All time | Photo count deleted + **storage recovered** (bytes) |

### Breakdown chart

Simple bar chart grouped by day, month, or year (selectable period). Each row shows a date label, a compact bar, and a right-aligned count. Cards in the overview grids are equal height per row.

Updates automatically when deletions change.

---

## Settings

Accessible from the app bar (except in swipe mode).

| Section | Content |
|---------|---------|
| **About** | App name and short description |
| **Trash** | Explains queue → review → OS trash flow |
| **Android only — Media management** | Link to system settings for optional reduced delete prompts (not available on all devices/builds) |

---

## Sessions and persistence

ISwipe remembers your progress so you can stop and continue later.

### Session types

| Type | Created when | Shown in Continue |
|------|--------------|-------------------|
| **Album** | You sort a folder from Gallery | Yes — if folder is not fully sorted |
| **Category** | You sort a cleanup queue or duplicate group | No (hidden from Continue) |

### What is stored per session

- Title (album name or category label)
- Total photo count and current index
- Counts: kept, deleted, later, favorite
- Full **decision log** (every action with timestamp)
- Asset ID list for category sessions

### Session history (in swipe mode)

Open via the history icon. See every decision in the current session and **undo any one** — not just the last action.

---

## Local data and privacy

| Data | Storage | Purpose |
|------|---------|---------|
| Reviewed/kept asset IDs | SQLite | Green checkmarks in folder view |
| Deletion records + thumbnails | SQLite + app files | Deleted tab + analytics |
| Cleanup sessions + decisions | SQLite | Resume + undo-any |
| Triage scan cache | SQLite | Fast Home categories |
| Favorites / Later lists | SQLite | Secondary actions |
| Pending deletes | In memory during session | Queue before review |

**Nothing is uploaded.** No account is required.

---

## Permissions

### Android

- Read media images (and video entry in manifest for library compatibility).
- Optional: Media management (`MANAGE_MEDIA`) to reduce per-delete system dialogs — often unavailable on sideloaded/debug builds.

Gallery access uses **`photo_manager`** directly (not a separate permission package for reading albums).

### iOS

- Photo library read access; limited access is supported.
- Undo from system Recently Deleted is not available via API — user must restore manually in Photos.

---

## Design and feel

- **Light and dark** themes follow system setting.
- **Inter** font via Google Fonts.
- iOS-style blue accent, rounded cards, minimal chrome.
- Custom empty states for Home, Gallery, Deleted.
- Apple-like, premium-minimal aesthetic per product direction.

---

## Platform differences (summary)

| Topic | Android | iOS |
|-------|---------|-----|
| Album/folder list | All media folders API exposes | Photo library albums only |
| Delete confirm | System dialog per batch; optional MANAGE_MEDIA | System behavior |
| Undo from trash | Supported when asset reference held | Manual in Photos app |
| Duplicate folder path | Usually `relativePath` | Often full parent path |
| Screenshot detection | Filename + album heuristics | + asset subtype |

---

## Known limitations (current version)

- **Video triage** is not implemented (photos only for cleanup scan).
- **Compare mode** for duplicates (side-by-side zoom) is planned for a later phase.
- **Near-duplicates** (similar but not identical) are not detected — exact duplicates only.
- Triage cache from older app versions may need a **rescan** after updates.
- Session progress bar can be approximate after in-memory deck changes.
- Smart albums, premium tier, and advanced AI features are **Phase 2+**.

---

## Roadmap direction (not yet built)

From the competitive product plan — future phases may add:

- Compare mode and “pick best” for duplicate groups
- Near-duplicate and burst detection
- Video-first cleanup (size-weighted queues)
- Smart Start ordering (confidence × storage impact)
- Album filing on keep (Slidebox-style)
- Optional premium intelligence tier (never paywall basic swiping)

See [`agent/COMPETITIVE_RESUME.md`](../agent/COMPETITIVE_RESUME.md) for full product vision.

---

## For developers and agents

| Document | Purpose |
|----------|---------|
| [`documentation/APP_PRESENTATION.md`](APP_PRESENTATION.md) | **This file** — user-facing behavior and product presentation |
| [`agent/PROGRESS.md`](../agent/PROGRESS.md) | Append-only dev log (problems, fixes, file changes) |
| [`agent/REQUIREMENTS.md`](../agent/REQUIREMENTS.md) | Scope and requirements |
| [`agent/SESSION_SCHEMA.md`](../agent/SESSION_SCHEMA.md) | SQLite session schema |
| [`agent/COMPETITIVE_RESUME.md`](../agent/COMPETITIVE_RESUME.md) | Market positioning and roadmap |

**When you change behavior**, update this presentation doc in the same PR/session so it stays accurate.
