#!/bin/bash
# DSH change-watchdog: wake the DSH reviewer the moment the coding session
# touches code. Polls a cheap signature (HEAD + dirty-file fingerprint of
# src/ and specs-local/); EXITS (with a report) as soon as it changes, which
# delivers a job-finished notification to the reviewer. The reviewer then
# diffs, writes DSH-REVIEW.md, and restarts this watchdog with a fresh
# baseline. DSH-REVIEW.md and .dsh-watch.* are excluded so the reviewer's own
# writes never self-trigger.
REPO=/Users/sqlrush/pgrac-dsh
INTERVAL=60

sig() {
  local h d
  h=$(git -C "$REPO" log -1 --pretty=%h 2>/dev/null)
  d=$(cd "$REPO" && git status --porcelain -- src specs-local 2>/dev/null | cksum | cut -d' ' -f1)
  echo "$h|$d"
}

base=$(sig)
echo "change-watchdog armed: base=$base interval=${INTERVAL}s (job exits on first code change)"
while true; do
  sleep "$INTERVAL"
  cur=$(sig)
  if [ "$cur" != "$base" ]; then
    echo "FLASH-CHANGED base=$base cur=$cur — wake DSH reviewer now"
    exit 0
  fi
done
