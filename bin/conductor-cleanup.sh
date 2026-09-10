#!/bin/bash
# conductor-cleanup.sh — reclaim disk from orphaned Conductor worktrees and dead Xcode DerivedData.
#
# Why: Conductor archives workspaces but leaves the worktree directories behind
# (each ~1GB node_modules + up to ~7GB ios build output), and Xcode keeps a
# ~4.5GB DerivedData folder per worktree *path*. Disk fills, the Spotlight index
# on /System/Volumes/Data goes read-only, and Cmd+Space stops finding apps.
#
# Safe by construction:
#   - Worktree dirs are only deleted when git no longer recognizes them
#     (their gitdir pointer is dead — Conductor already deregistered them,
#     so all commits live in the parent repo's .git) AND nothing inside was
#     modified in the last GRACE_DAYS.
#   - DerivedData folders are only deleted when their WorkspacePath no longer
#     exists on disk (pure regenerable build cache).
#   - Live/registered worktrees and anything recently touched are never touched.
#
# Usage: conductor-cleanup [--dry-run]
# Runs daily via launchd/com.cnord.conductor-cleanup.plist (linked into
# ~/Library/LaunchAgents by dotbot; load with `launchctl bootstrap gui/$UID <plist>`)
set -uo pipefail

WORKSPACES="$HOME/conductor/workspaces"
DERIVED="$HOME/Library/Developer/Xcode/DerivedData"
GRACE_DAYS=7
MIN_FREE_GB=50
LOG="$HOME/Library/Logs/conductor-cleanup.log"
DRY_RUN="${1:-}"

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $*" | tee -a "$LOG"; }

freed_kb=0
remove_dir() {
  local d="$1" reason="$2"
  local kb
  kb=$(du -sk "$d" 2>/dev/null | cut -f1)
  if [ "$DRY_RUN" = "--dry-run" ]; then
    log "DRY-RUN would delete [$reason, $((kb / 1024))MB]: $d"
  else
    rm -rf "$d" && { freed_kb=$((freed_kb + kb)); log "deleted [$reason, $((kb / 1024))MB]: $d"; }
  fi
}

log "=== conductor-cleanup start ${DRY_RUN:+(dry run)}"

# --- 1. Orphaned Conductor worktrees --------------------------------------
for d in "$WORKSPACES"/*/*/; do
  [ -d "$d" ] || continue
  d="${d%/}"
  # Skip anything with recent activity, whatever its state.
  if [ -n "$(find "$d" -newermt "-${GRACE_DAYS} days" -print -quit 2>/dev/null)" ]; then
    continue
  fi
  gitfile="$d/.git"
  if [ -f "$gitfile" ]; then
    gitdir=$(sed -n 's/^gitdir: //p' "$gitfile")
    if [ -n "$gitdir" ] && [ ! -e "$gitdir" ]; then
      remove_dir "$d" "orphaned worktree"
    fi
    # gitdir still exists -> live registered worktree, leave it alone
  elif [ ! -e "$gitfile" ]; then
    remove_dir "$d" "stale non-git leftover"
  fi
done

# --- 2. DerivedData for workspaces that no longer exist -------------------
for d in "$DERIVED"/*/; do
  [ -d "$d" ] || continue
  d="${d%/}"
  [ "$(basename "$d")" = "CompilationCache.noindex" ] && continue
  [ -f "$d/info.plist" ] || continue
  wp=$(defaults read "$d/info" WorkspacePath 2>/dev/null) || continue
  if [ -n "$wp" ] && [ ! -e "$wp" ]; then
    remove_dir "$d" "dead DerivedData"
  fi
done

# --- 3. Low-disk early warning (before Spotlight's index breaks) ----------
avail_gb=$(df -g /System/Volumes/Data | awk 'NR==2 {print $4}')
if [ -n "$avail_gb" ] && [ "$avail_gb" -lt "$MIN_FREE_GB" ]; then
  log "WARNING: only ${avail_gb}GB free on /System/Volumes/Data"
  osascript -e "display notification \"Only ${avail_gb} GB free. Spotlight breaks when the disk fills — clear space soon.\" with title \"Low disk space\" sound name \"Basso\"" 2>/dev/null
fi

log "=== done, freed ~$((freed_kb / 1024 / 1024))GB (${avail_gb:-?}GB free)"
