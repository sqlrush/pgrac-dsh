#!/bin/bash
# DSH watcher v2: scan coding session progress every 900s.
# Alerts -> DSH-REVIEW.md (🔴), history -> .dsh-watch.log.
# Alert rules:
#   (a) STUCK: 2 consecutive cycles (~30 min) with zero change in
#       HEAD / uncommitted files / t243 reglog / latest src edit;
#   (b) REGRESSION: a NEW completed t243 run produced FEWER oks than the
#       previous completed run (progress went backwards);
#   (c) STARTUP-LEVEL: a completed run bailed with <=3 oks (bootstrap/
#       node-start breakage — the worst class).
# Mid-run cycles are provisional: no (b)/(c) alerts while prove is active.
REPO=/Users/sqlrush/pgrac-dsh
LOG=$REPO/.dsh-watch.log
REVIEW=$REPO/DSH-REVIEW.md
cycle=0
prev_fp=""
nochange=0
stuck_episode=0
prev_oks_final=-1
prev_reg_epoch=0
best_oks=0

snapshot() {
  local head headtime uncommitted regtime oks latest_edit fp
  local reg_epoch bail run_active

  head=$(git -C "$REPO" log -1 --pretty=%h 2>/dev/null)
  headtime=$(git -C "$REPO" log -1 --pretty='%ad' --date=format:'%H:%M' 2>/dev/null)
  uncommitted=$(git -C "$REPO" status --short 2>/dev/null | wc -l | tr -d ' ')
  latest_edit=$(find "$REPO/src" \( -name '*.c' -o -name '*.h' \) -exec stat -f '%Sm %N' -t '%H:%M' {} \; 2>/dev/null | sort -r | head -1)
  reglog="$REPO/src/test/cluster_tap/tmp_check/log/regress_log_243_wal_thread_2node_shared_root"
  reg_epoch=0; oks=0; bail=0; regtime="none"
  if [ -f "$reglog" ]; then
    reg_epoch=$(stat -f '%m' "$reglog" 2>/dev/null)
    regtime=$(stat -f '%Sm' -t '%H:%M' "$reglog" 2>/dev/null)
    oks=$(grep -cE 'ok [0-9]+ -' "$reglog" 2>/dev/null | tr -d ' ')
    bail=$(grep -c 'Bail out!' "$reglog" 2>/dev/null | tr -d ' ')
  fi
  run_active=$(pgrep -f 't/243_wal_thread_2node_shared_root' 2>/dev/null | wc -l | tr -d ' ')

  fp="$head|$uncommitted|$reg_epoch|$oks|$latest_edit"
  echo "$(date '+%m-%d %H:%M:%S') c=$cycle HEAD=$head@$headtime uncommitted=$uncommitted t243=${oks}ok@$regtime bail=$bail active=$run_active" >> "$LOG"

  # (a) stuck
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

  # (b)/(c) regression alerts — only for COMPLETED runs (no prove active)
  if [ "$run_active" = "0" ] && [ "$reg_epoch" -gt 0 ] && [ "$reg_epoch" != "$prev_reg_epoch" ]; then
    if [ "$prev_oks_final" -ge 0 ] && [ "$oks" -lt "$prev_oks_final" ]; then
      {
        echo ""
        echo "---"
        echo "🔴 [DSH-WATCH $(date '+%m-%d %H:%M')] t243 回归：上一轮完成 $prev_oks_final ok，新一轮完成仅 ${oks} ok（reglog $regtime）。"
        echo "   DSH 建议：先 diff 本轮相对上一绿轮的源码改动（git diff / 最近 uncommitted 变更），二分定位回归提交，"
        echo "   优先恢复上轮绿态（20:19 run-30 的 21ok）再继续；不要把回归归因为环境问题。"
      } >> "$REVIEW"
      echo "$(date '+%m-%d %H:%M:%S') 🔴 REGRESSION $prev_oks_final->$oks ok flagged -> DSH-REVIEW.md" >> "$LOG"
    fi
    if [ "$bail" -gt 0 ] && [ "$oks" -le 3 ]; then
      {
        echo ""
        echo "---"
        echo "🔴 [DSH-WATCH $(date '+%m-%d %H:%M')] t243 启动级失败：跑批 bail 且仅 ${oks} ok（reglog $regtime）——节点启动/bootstrap 层被打断。"
        echo "   DSH 建议：查 tmp_check/log 两节点日志尾部的第一个 FATAL/PANIC；这类回归通常来自最新改动，先回退再修。"
      } >> "$REVIEW"
      echo "$(date '+%m-%d %H:%M:%S') 🔴 STARTUP-BAIL ${oks}ok flagged -> DSH-REVIEW.md" >> "$LOG"
    fi
    # (d) milestone guardrail: a completed run reached a NEW ok high-water mark.
    # Auto-snapshot the working tree (tag dsh-flash-wip-*) so the best state
    # survives even if the coding session never commits it.
    if [ "$oks" -gt "$best_oks" ] && [ "$(git -C "$REPO" status --porcelain 2>/dev/null | wc -l | tr -d ' ')" -gt 0 ]; then
      local snap sha ts
      ts=$(date '+%m%d-%H%M')
      sha=$(git -C "$REPO" stash create "dsh-snapshot ${oks}ok" 2>/dev/null)
      if [ -n "$sha" ]; then
        git -C "$REPO" tag -f "dsh-flash-wip-$ts" "$sha" 2>/dev/null
        echo "$(date '+%m-%d %H:%M:%S') ✅ SNAPSHOT new-high ${oks}ok -> tag dsh-flash-wip-$ts ($sha)" >> "$LOG"
      fi
      best_oks=$oks
    fi
    prev_oks_final=$oks
    prev_reg_epoch=$reg_epoch
  fi
}

while true; do
  cycle=$((cycle+1))
  snapshot
  sleep 900
done
