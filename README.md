# Doc-Sync: Event-Driven File Sync System

> **Platform:** macOS (Apple Silicon)  
> **Tools:** rclone + fswatch + launchd

Event-driven bidirectional file sync between `~/Documents`, Google Drive, and iCloud Drive.

## Architecture

```
~/Documents (local, source of truth)
    ├── rclone sync ──► Google Drive (/EdenTnS)
    └── rclone sync ──► iCloud Drive (/EdenTnS)

fswatch monitors local + iCloud folders
  → detects create / modify / delete events
  → triggers rclone sync after 60s debounce
  → records versioned changelog

Scheduled full sync at 09:00, 13:00, 18:00 daily
Periodic GDrive pull every 15 min (covers remote-only changes)
```

## Tools & Frameworks

- **[rclone](https://rclone.org)** v1.73.2 — Cloud storage sync engine
- **[fswatch](https://github.com/emcrisostomo/fswatch)** v1.18.3 — Cross-platform file change monitor
- **[launchd](https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPSystemStartup/Chapters/CreatingLaunchdJobs.html)** — macOS service management
- **[Homebrew](https://brew.sh)** — Package manager

## Installation

```bash
brew install rclone fswatch
```

## Scripts

| Script | Purpose |
|--------|---------|
| `sync-to-gdrive.sh` | Local → Google Drive |
| `sync-to-icloud.sh` | Local → iCloud Drive |
| `sync-from-gdrive.sh` | Google Drive → Local |
| `sync-from-icloud.sh` | iCloud Drive → Local |
| `sync-all.sh` | Master sync (push/pull/all) with locking |
| `doc-sync-watcher.sh` | fswatch event-driven watcher |
| `record-changes.sh` | Changelog recorder with versioning |
| `pull-gdrive-with-changelog.sh` | GDrive pull wrapper with changelog |
| `stop-watcher.sh` | Stop watcher gracefully |
| `test-sync.sh` | 16-point test suite |
| `filter-rules.txt` | rclone exclusion rules |

## launchd Services

| Plist | Purpose |
|-------|---------|
| `com.brian.docsync-watcher.plist` | Starts fswatch watcher on login (KeepAlive) |
| `com.brian.docsync-gdrive-pull.plist` | Pulls GDrive changes every 15 min |
| `com.brian.docsync-scheduled.plist` | Full sync at 09:00, 13:00, 18:00 daily |

## Changelog

Every sync records a versioned entry at `~/.local/share/doc-sync/changelog.txt`:

```
================================================================
Version : v1
Date    : 2026-03-16 14:12:12
Action  : Local → GDrive + iCloud
Summary : +1 created, ~0 modified, -0 deleted
----------------------------------------------------------------
  [CREATE]  example.txt
================================================================
```

## Common Commands

```bash
# Manual full sync
~/.local/bin/doc-sync/sync-all.sh

# Push only / Pull only
~/.local/bin/doc-sync/sync-all.sh push
~/.local/bin/doc-sync/sync-all.sh pull

# Run test suite
~/.local/bin/doc-sync/test-sync.sh

# View changelog
cat ~/.local/share/doc-sync/changelog.txt

# View watcher log
tail -f ~/.local/share/doc-sync/logs/watcher.log

# Stop / Restart watcher
~/.local/bin/doc-sync/stop-watcher.sh
launchctl unload ~/Library/LaunchAgents/com.brian.docsync-watcher.plist
launchctl load ~/Library/LaunchAgents/com.brian.docsync-watcher.plist

# Dry-run (preview without changes)
~/.local/bin/doc-sync/sync-to-gdrive.sh --dry-run
```

## Setup

1. Install: `brew install rclone fswatch`
2. Configure rclone: `rclone config` (add `gdrive` and `icloud` remotes)
3. Copy scripts to `~/.local/bin/doc-sync/`
4. Copy plists to `~/Library/LaunchAgents/`
5. Load services: `launchctl load ~/Library/LaunchAgents/com.brian.docsync-*.plist`
