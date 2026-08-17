#!/bin/bash
# DSH watcher: scan coding session progress every 900s; flag stuck state.
REPO=/Users/sqlrush/pgrac-dsh
LOG=$REPO/.dsh-watch.log
REVIEW=$REPO/DSH-REVIEW.md
cycle=0
prev_fp=""
nochange=0
stuck_episode=0

snapshot() {
  local head headtime uncommitted regtime oks latest_edit fp
  head=$(git -C "$REPO" log -1 --pretty=%h 2>/dev/null)
  headtime=$(git -C "$REPO" log -1 --pretty='%ad' --date=format:'%H:%M' 2>/dev/null)
  uncommitted=$(git -C "$REPO" status --short 2>/dev/null | wc -l | tr -d ' ')
  latest_edit=$(find "$REPO/src" \( -name '*.c' -o -name '*.h' \) -exec stat -f '%Sm %N' -t '%H:%M' {} \; 2>/dev/null | sort -r | head -1)
  reglog="$REPO/src/test/cluster_tap/tmp_check/log/regress_log_243_wal_thread_2node_shared_root"
  if [ -f "$reglog" ]; then
    regtime=$(stat -f '%Sm' -t '%H:%M' "$reglog" 2>/dev/null)
    oks=$(grep -cE 'ok [0-9]+ -' "$reglog" 2>/dev/null | tr -d ' ')
  else
    regtime="none"; oks=0
  fi
  fp="$head|$uncommitted|$regtime|$oks|$latest_edit"
  echo "$(date '+%m-%d %H:%M:%S') c=$cycle HEAD=$head@$headtime uncommitted=$uncommitted t243=${oks}ok@$regtime" >> "$LOG"
  if [ "$fp" = "$prev_fp" ]; then
    nochange=$((nochange+1))
  else
    nochange=0
  fi
  if [ "$nochange" -ge 2 ] && [ "$stuck_episode" -eq 0 ]; then
    stuck_episode=1
    {
      echo ""
      echo "---"
      echo "🔴 [DSH-WATCH $(date '+%m-%d %H:%M')] 疑似卡住：连续 2 个扫描周期（约 30 分钟）HEAD/工作区/t243 均无任何变化。"
      echo "   last: HEAD=$head uncommitted=$uncommitted t243=${oks}ok@$regtime"
      echo "   DSH 建议：若确在等待（长跑批/思考），忽略本条；若在绕圈，请回到 P6-RESUME.md 最短路或读本条之前 DSH 的复审补记。"
    } >> "$REVIEW"
    echo "$(date '+%m-%d %H:%M:%S') 🔴 STUCK flagged -> DSH-REVIEW.md" >> "$LOG"
  fi
  if [ "$nochange" -lt 2 ]; then stuck_episode=0; fi
  prev_fp="$fp"
}

while true; do
  cycle=$((cycle+1))
  snapshot
  sleep 900
done
