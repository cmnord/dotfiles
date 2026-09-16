#!/bin/bash
# conductor-cleanup.sh — reclaim disk from stale workspaces, DerivedData and Colima caches.
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
#   - Any other checkout is deleted only when git proves it holds nothing
#     unique: no .git, zero commits, or a clean tree fully on a remote — and
#     no KEEP_IGNORED file. Otherwise only its gitignored output goes.
#   - DerivedData folders are only deleted when their WorkspacePath no longer
#     exists on disk (pure regenerable build cache).
#   - Live/registered worktrees and anything recently touched are never touched.
#   - Every git check fails closed: any error, or any doubt, means keep.
#   - Colima maintenance preserves containers, volumes and detached disks;
#     unavailable tools/profiles are skipped and stopped VMs are never started.
#
# Usage: conductor-cleanup.sh [--dry-run]
# Runs daily via launchd/com.cnord.conductor-cleanup.plist (linked into
# ~/Library/LaunchAgents by dotbot; load with `launchctl bootstrap gui/$UID <plist>`)
# Install with ./install. First back up/move aside any regular-file copy at
# ~/bin/conductor-cleanup.sh so Dotbot can link it; relink only replaces symlinks.
# Check --dry-run, then bootout/bootstrap the loaded job to pick up PATH changes.
set -uo pipefail

WORKSPACES="$HOME/conductor/workspaces"
DERIVED="$HOME/Library/Developer/Xcode/DerivedData"
GRACE_DAYS=7
MIN_FREE_GB=50
LOG="$HOME/Library/Logs/conductor-cleanup.log"
DRY_RUN="${1:-}"

# Gitignored but NOT regenerable — the short, stable inverse of a cache list.
# Basenames only; a protected file inside a wholly-ignored dir is not seen.
KEEP_IGNORED='(^|/)(\.env(\..*)?|\.envrc|\.claude|\.direnv|.*\.local)/?$'

ignored_in() { git -C "$1" clean -Xdn 2>/dev/null | sed -n 's/^Would remove //p'; }

mkdir -p "$(dirname "$LOG")" 2>/dev/null
# stderr has nowhere to go under launchd, and log() tees only stdout.
[ -t 2 ] || exec 2>>"$LOG"
log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $*" | tee -a "$LOG"; }

# Avail KB (df field 4 on both BSD and GNU df).
free_kb() { df -k /System/Volumes/Data 2>/dev/null | awk 'NR==2 {print $4}'; }

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

# True when git proves every unique byte here also exists elsewhere: a remote
# exists, the tree is clean, and no ref is missing from it. --all, not
# --branches: a stash, local tag or detached HEAD holds commits no branch points
# at, and a stash leaves the worktree looking clean. Submodules keep objects
# under .git/modules that --all never walks, so a repo with one is kept.
# Caveat: remote refs here are cached, so a branch force-pushed away on the
# server still looks present.
fully_pushed() {
  local d="$1" out
  [ -n "$(git -C "$d" remote 2>/dev/null)" ] || return 1
  [ -z "$(git -C "$d" submodule status --recursive 2>/dev/null)" ] || return 1
  out=$(git -C "$d" status --porcelain 2>/dev/null) || return 1
  [ -z "$out" ] || return 1
  out=$(git -C "$d" log --all --not --remotes --format=%H 2>/dev/null) || return 1
  [ -z "$out" ]
}

purge_ignored() {
  local d="$1" sub
  while IFS= read -r sub; do
    remove_dir "$d/${sub%/}" "gitignored, regenerable"
  done < <(ignored_in "$d" | grep -Ev "$KEEP_IGNORED")
}

# Docker images/build cache live inside Colima's VM disk, outside the workspace
# cleanup below. Prune old unused images/cache, then trim the guest filesystem
# so freed guest blocks can return space to macOS. Only target the running
# default local profile. The subshell isolates Docker/Colima environment changes.
cleanup_colima() (
  local endpoint expected="unix://$HOME/.colima/default/docker.sock" output failed=0
  if ! command -v docker >/dev/null 2>&1 || ! command -v colima >/dev/null 2>&1; then
    log "SKIP Colima maintenance: docker or colima is not installed"
    return 0
  fi
  if [ ! -d "$HOME/.colima/default" ]; then
    log "SKIP Colima maintenance: default profile is not installed"
    return 0
  fi

  # Neither the caller's Docker endpoint/config nor a custom Colima/Lima home
  # may redirect pruning or guest trim to another machine/profile.
  unset DOCKER_HOST DOCKER_CONTEXT DOCKER_TLS DOCKER_TLS_VERIFY DOCKER_CERT_PATH
  unset BUILDX_BUILDER COLIMA_PROFILE LIMA_HOME XDG_CONFIG_HOME
  export DOCKER_CONFIG="$HOME/.docker" COLIMA_HOME="$HOME/.colima"
  if ! output=$(colima --profile default status 2>&1); then
    log "SKIP Colima maintenance: default profile is stopped or unavailable: $output"
    return 0
  fi
  if ! endpoint=$(docker --context colima context inspect colima --format '{{.Endpoints.docker.Host}}' 2>&1); then
    log "SKIP Colima maintenance: colima Docker context is unavailable: $endpoint"
    return 0
  fi
  if [ "$endpoint" != "$expected" ]; then
    log "ERROR: refusing Colima maintenance: colima context does not point to $expected"
    return 1
  fi
  # Pin the verified context's socket, even if the context changes mid-run.
  if ! output=$(docker --host "$expected" info 2>&1); then
    log "ERROR: local Colima Docker daemon is unavailable: $output"
    return 1
  fi
  if [ "$DRY_RUN" = "--dry-run" ]; then
    log "DRY-RUN would prune unused images created over 168h ago on $expected"
    log "DRY-RUN would prune dangling build cache unused for 168h on $expected"
    log "DRY-RUN would trim default Colima /mnt/lima-colima (sudo -n fstrim -v)"
    return 0
  fi

  # Image 'until' is creation age, not time since last use. Images referenced
  # by any container (including stopped containers) are retained.
  log "Colima: pruning unused images created over 168h ago"
  if ! docker --host "$expected" image prune --all --force --filter until=168h 2>&1 | tee -a "$LOG"; then
    log "ERROR: Colima image prune failed"
    failed=1
  fi
  # BuildKit's 'until' is time since last use. Keep the conservative default
  # dangling-cache scope (no --all); never prune containers or volumes.
  # Disable CLI forwarding to Buildx (including configured builder aliases).
  # The Engine API still prunes BuildKit cache on the pinned local daemon.
  log "Colima: pruning dangling build cache unused for 168h"
  if ! DOCKER_BUILDKIT=0 docker --host "$expected" builder prune --force --filter until=168h 2>&1 | tee -a "$LOG"; then
    log "ERROR: Colima builder prune failed"
    failed=1
  fi
  # One trim per run: tomorrow's trim can catch delayed Docker garbage
  # collection. Its reported range is NOT measured host space reclaimed.
  log "Colima: trimming /mnt/lima-colima; Docker/trim bytes are not host disk recovery"
  if ! colima --profile default ssh -- sudo -n fstrim -v /mnt/lima-colima 2>&1 | tee -a "$LOG"; then
    log "ERROR: Colima filesystem trim failed"
    failed=1
  fi
  return "$failed"
)

log "=== conductor-cleanup start ${DRY_RUN:+(dry run)}"
free_start_kb=$(free_kb)

# --- 1. Orphaned Conductor worktrees --------------------------------------
for d in "$WORKSPACES"/*/*/; do
  [ -d "$d" ] || continue
  d="${d%/}"
  # Skip anything with recent activity, whatever its state.
  # .git is pruned: the checks below refresh .git/index, which would else let
  # one run reset every repo's idle clock.
  if [ -n "$(find "$d" -name .git -prune -o -newermt "-${GRACE_DAYS} days" -print -quit 2>/dev/null)" ]; then
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
  # Holds a .env & co, which exists nowhere else: never removed wholesale, but
  # still gives up its caches.
  elif ignored_in "$d" | grep -Eq "$KEEP_IGNORED"; then
    purge_ignored "$d"
  # A .git with zero commits (an rsynced copy, a bare `git init`) holds no
  # history, so protects the tree no more than no .git at all. A git error
  # yields "" here, not 0, so anything unreadable is kept.
  elif [ "$(git -C "$d" rev-list --all --count 2>/dev/null)" = 0 ]; then
    remove_dir "$d" "throwaway checkout, no commits"
  elif fully_pushed "$d"; then
    remove_dir "$d" "clean checkout, fully pushed"
  else
    purge_ignored "$d"
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

# --- 3. Default local Colima images, build cache and guest trim -----------
cleanup_status=0
cleanup_colima || cleanup_status=1

# --- 4. Low-disk early warning (before Spotlight's index breaks) ----------
avail_gb=$(df -g /System/Volumes/Data | awk 'NR==2 {print $4}')
if [ -n "$avail_gb" ] && [ "$avail_gb" -lt "$MIN_FREE_GB" ]; then
  log "WARNING: only ${avail_gb}GB free on /System/Volumes/Data"
  osascript -e "display notification \"Only ${avail_gb} GB free. Spotlight breaks when the disk fills — clear space soon.\" with title \"Low disk space\" sound name \"Basso\"" 2>/dev/null
fi

# Report the measured df delta: pnpm hardlinks node_modules into a shared
# store, so the summed du over-counts it.
delta_kb=$(( $(free_kb) - ${free_start_kb:-0} ))
log "=== done, freed $((delta_kb / 1024))MB measured (${avail_gb:-?}GB free; du-summed ~$((freed_kb / 1024))MB over-counts hardlinks)"
exit "$cleanup_status"
