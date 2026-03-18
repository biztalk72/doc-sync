# Doc-Sync: Event-Driven File Sync System
# Doc-Sync: 이벤트 기반 파일 동기화 시스템

> **Platform / 플랫폼:** macOS (Apple Silicon)  
> **Tools / 도구:** rclone + fswatch + launchd  
> **Date / 날짜:** 2026-03-16

---

## Overview / 개요

Event-driven bidirectional file sync between `~/Documents`, Google Drive, and iCloud Drive.

`~/Documents`, Google Drive, iCloud Drive 간 이벤트 기반 양방향 파일 동기화 시스템입니다.

## Architecture / 아키텍처

```
~/Documents (local source of truth / 로컬 원본)
    ├── rclone sync ──► Google Drive (/EdenTnS)
    └── rclone sync ──► iCloud Drive (/EdenTnS)

fswatch monitors local + iCloud folders
  → detects create / modify / delete events
  → triggers rclone sync after 60s debounce
  → records versioned changelog

fswatch가 로컬 + iCloud 폴더를 감시
  → 생성 / 수정 / 삭제 이벤트 감지
  → 60초 디바운스 후 rclone sync 실행
  → 버전별 변경 이력 기록

Scheduled full sync / 예약 전체 동기화:
  → 09:00, 13:00, 18:00 daily / 매일
Periodic GDrive pull / 주기적 GDrive 풀:
  → every 15 min / 15분 간격
```

---

## Tools & Frameworks / 도구 및 프레임워크

- **[rclone](https://rclone.org)** v1.73.2 — Cloud storage sync engine / 클라우드 스토리지 동기화 엔진
- **[fswatch](https://github.com/emcrisostomo/fswatch)** v1.18.3 — Cross-platform file change monitor / 크로스 플랫폼 파일 변경 감시
- **[launchd](https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPSystemStartup/Chapters/CreatingLaunchdJobs.html)** — macOS service management / macOS 서비스 관리 (내장)
- **[Homebrew](https://brew.sh)** — Package manager / 패키지 관리자

### Installation / 설치

```bash
brew install rclone fswatch
```

---

## Scripts / 스크립트

| Script / 스크립트 | Purpose / 용도 |
|--------|---------|
| `sync-to-gdrive.sh` | Local → Google Drive / 로컬 → 구글 드라이브 |
| `sync-to-icloud.sh` | Local → iCloud Drive / 로컬 → 아이클라우드 |
| `sync-from-gdrive.sh` | Google Drive → Local / 구글 드라이브 → 로컬 |
| `sync-from-icloud.sh` | iCloud Drive → Local / 아이클라우드 → 로컬 |
| `sync-all.sh` | Master sync with locking / 잠금 기반 마스터 동기화 (push/pull/all) |
| `doc-sync-watcher.sh` | fswatch event-driven watcher / fswatch 이벤트 감시자 |
| `record-changes.sh` | Changelog recorder with versioning / 버전별 변경 이력 기록기 |
| `pull-gdrive-with-changelog.sh` | GDrive pull wrapper with changelog / GDrive 풀 + 변경 이력 |
| `stop-watcher.sh` | Stop watcher gracefully / 감시자 정상 종료 |
| `test-sync.sh` | 16-point test suite / 16개 항목 테스트 |
| `filter-rules.txt` | rclone exclusion rules / rclone 제외 규칙 |

---

## launchd Services / launchd 서비스

| Plist | Purpose / 용도 |
|-------|---------|
| `com.brian.docsync-watcher.plist` | Starts fswatch on login (KeepAlive) / 로그인 시 fswatch 자동 시작 |
| `com.brian.docsync-gdrive-pull.plist` | Pulls GDrive changes every 15 min / 15분마다 GDrive 변경사항 가져오기 |
| `com.brian.docsync-scheduled.plist` | Full sync at 09:00, 13:00, 18:00 daily / 매일 09시, 13시, 18시 전체 동기화 |

---

## Changelog / 변경 이력

Every sync records a versioned entry at `~/.local/share/doc-sync/changelog.txt`.

모든 동기화는 `~/.local/share/doc-sync/changelog.txt`에 버전별 항목을 기록합니다.

```
================================================================
Version : v1
Date    : 2026-03-16 14:12:12
Action  : Local → GDrive + iCloud
Summary : +1 created, ~0 modified, -0 deleted
----------------------------------------------------------------
  [CREATE]  example.txt
================================================================

================================================================
Version : v2
Date    : 2026-03-16 14:12:14
Action  : Local → GDrive + iCloud
Summary : +0 created, ~1 modified, -0 deleted
----------------------------------------------------------------
  [MODIFY]  example.txt
================================================================

================================================================
Version : v3
Date    : 2026-03-16 14:12:15
Action  : Local → GDrive + iCloud
Summary : +0 created, ~0 modified, -1 deleted
----------------------------------------------------------------
  [DELETE]  example.txt
================================================================
```

---

## Directory Structure / 디렉토리 구조

```
~/.local/bin/doc-sync/             # Scripts / 스크립트
    ├── sync-to-gdrive.sh
    ├── sync-to-icloud.sh
    ├── sync-from-gdrive.sh
    ├── sync-from-icloud.sh
    ├── sync-all.sh
    ├── doc-sync-watcher.sh
    ├── record-changes.sh
    ├── pull-gdrive-with-changelog.sh
    ├── stop-watcher.sh
    ├── test-sync.sh
    └── filter-rules.txt

~/.local/share/doc-sync/           # Data & Logs / 데이터 및 로그
    ├── changelog.txt              # Change history / 변경 이력
    ├── version.txt                # Version counter / 버전 카운터
    ├── snapshot-*.txt             # File state snapshots / 파일 상태 스냅샷
    └── logs/
        ├── watcher.log
        ├── sync-to-gdrive.log
        ├── sync-to-icloud.log
        ├── sync-from-gdrive.log
        ├── sync-from-icloud.log
        └── sync-all.log

~/Library/LaunchAgents/            # Auto-start services / 자동 시작 서비스
    ├── com.brian.docsync-watcher.plist
    ├── com.brian.docsync-gdrive-pull.plist
    └── com.brian.docsync-scheduled.plist
```

---

## Common Commands / 주요 명령어

```bash
# Manual full sync / 수동 전체 동기화
~/.local/bin/doc-sync/sync-all.sh

# Push only (local → remotes) / 푸시만 (로컬 → 원격)
~/.local/bin/doc-sync/sync-all.sh push

# Pull only (remotes → local) / 풀만 (원격 → 로컬)
~/.local/bin/doc-sync/sync-all.sh pull

# Run test suite / 테스트 실행 (16개 항목)
~/.local/bin/doc-sync/test-sync.sh

# View changelog / 변경 이력 보기
cat ~/.local/share/doc-sync/changelog.txt

# View watcher log / 감시자 로그 보기
tail -f ~/.local/share/doc-sync/logs/watcher.log

# Stop watcher / 감시자 중지
~/.local/bin/doc-sync/stop-watcher.sh

# Restart watcher / 감시자 재시작
~/.local/bin/doc-sync/stop-watcher.sh
launchctl unload ~/Library/LaunchAgents/com.brian.docsync-watcher.plist
launchctl load ~/Library/LaunchAgents/com.brian.docsync-watcher.plist

# Disable all services / 모든 서비스 비활성화
launchctl unload ~/Library/LaunchAgents/com.brian.docsync-*.plist

# Re-enable all services / 모든 서비스 재활성화
launchctl load ~/Library/LaunchAgents/com.brian.docsync-*.plist

# Reconfigure Google Drive OAuth / 구글 드라이브 OAuth 재설정
rclone config reconnect gdrive:

# Dry-run (preview without changes) / 드라이런 (변경 없이 미리보기)
~/.local/bin/doc-sync/sync-to-gdrive.sh --dry-run
~/.local/bin/doc-sync/sync-to-icloud.sh --dry-run
```

---

## How It Works / 동작 방식

1. **fswatch** monitors `~/Documents` and iCloud local folder for filesystem events  
   **fswatch**가 `~/Documents`와 iCloud 로컬 폴더의 파일 시스템 이벤트를 감시합니다

2. After 60s debounce, it triggers:  
   60초 디바운스 후 실행:
   - `record-changes.sh` — snapshots current state, diffs against previous, writes changelog  
     현재 상태를 스냅샷하고 이전과 비교하여 변경 이력을 기록
   - `sync-all.sh push` — runs `rclone sync` to Google Drive and iCloud Drive  
     `rclone sync`으로 Google Drive와 iCloud Drive에 동기화

3. **launchd timer** runs `sync-from-gdrive.sh` every 15 min to pull remote-only changes  
   **launchd 타이머**가 15분마다 `sync-from-gdrive.sh`를 실행하여 원격 변경사항을 가져옴

4. **Scheduled sync** runs full `sync-all.sh` at 09:00, 13:00, 18:00 daily  
   **예약 동기화**가 매일 09시, 13시, 18시에 `sync-all.sh` 전체 실행

5. When iCloud changes are detected, fswatch triggers a pull to `~/Documents`  
   iCloud 변경이 감지되면 fswatch가 `~/Documents`로 풀을 실행

6. All operations use **mkdir-based locking** to prevent overlapping syncs  
   모든 작업은 **mkdir 기반 잠금**으로 동시 실행을 방지

7. All operations log to `~/.local/share/doc-sync/logs/`  
   모든 작업은 `~/.local/share/doc-sync/logs/`에 로그를 기록

---

## Setup from Scratch / 처음부터 설정하기

```bash
# 1. Install tools / 도구 설치
brew install rclone fswatch

# 2. Configure rclone remotes / rclone 원격 설정
rclone config
#   → Add "gdrive" (Google Drive, OAuth)
#   → Add "icloud" (alias → ~/Library/Mobile Documents/com~apple~CloudDocs/EdenTnS)

# 3. Create directories / 디렉토리 생성
mkdir -p ~/.local/bin/doc-sync ~/.local/share/doc-sync/logs

# 4. Copy scripts / 스크립트 복사
cp *.sh ~/.local/bin/doc-sync/
cp filter-rules.txt ~/.local/bin/doc-sync/
chmod +x ~/.local/bin/doc-sync/*.sh

# 5. Copy launchd plists / launchd plist 복사
cp launchd/*.plist ~/Library/LaunchAgents/

# 6. Load services / 서비스 로드
launchctl load ~/Library/LaunchAgents/com.brian.docsync-watcher.plist
launchctl load ~/Library/LaunchAgents/com.brian.docsync-gdrive-pull.plist
launchctl load ~/Library/LaunchAgents/com.brian.docsync-scheduled.plist

# 7. Run test / 테스트 실행
~/.local/bin/doc-sync/test-sync.sh
```

---

## Safety Notes / 안전 참고사항

- `rclone sync` is a **mirror** operation — files deleted from source will be deleted from destination  
  `rclone sync`는 **미러링** 작업입니다 — 소스에서 삭제된 파일은 대상에서도 삭제됩니다
- Always use `--dry-run` first when testing changes to sync scripts  
  동기화 스크립트 변경 시 항상 `--dry-run`으로 먼저 테스트하세요
- The changelog provides an audit trail of all changes  
  변경 이력은 모든 변경의 감사 추적을 제공합니다
- The locking mechanism prevents race conditions between concurrent syncs  
  잠금 메커니즘이 동시 동기화 간의 경쟁 조건을 방지합니다
- Filter rules exclude macOS system files and temp files from sync  
  필터 규칙이 macOS 시스템 파일과 임시 파일을 동기화에서 제외합니다
