#!/bin/bash
# RF-ROOT P6 flake hunt: run t243 repeatedly, preserving each run's logs.
set -u
cd /Users/sqlrush/pgrac-dsh/src/test/cluster_tap || exit 1
mkdir -p /Users/sqlrush/pgrac-dsh/t243-runs
for i in $(seq 1 15); do
  echo "=== LOOP RUN $i $(date +%H:%M:%S) ==="
  pkill -9 -f walthreads_node 2>/dev/null
  sleep 1
  for id in $(ipcs -m | awk '/sqlrush/{print $2}'); do ipcrm -m "$id" 2>/dev/null; done
  for id in $(ipcs -s | awk '/sqlrush/{print $2}'); do ipcrm -s "$id" 2>/dev/null; done
  rm -rf tmp_check
  make check PROVE_TESTS='t/243_wal_thread_2node_shared_root.pl' > "/tmp/t243-loop-$i.log" 2>&1
  rc=$?
  okcount=$(grep -c '^ok$' tmp_check/log/regress_log_243_wal_thread_2node_shared_root 2>/dev/null || true)
  okcount=${okcount:-0}
  echo "run $i rc=$rc ok=$okcount"
  d="/Users/sqlrush/pgrac-dsh/t243-runs/run$(printf %02d "$i")-ok${okcount}"
  rm -rf "$d"
  mkdir -p "$d"
  cp -R tmp_check/log "$d/" 2>/dev/null
  cp "/tmp/t243-loop-$i.log" "$d/run.log" 2>/dev/null
  if [ "$okcount" -ge 22 ] 2>/dev/null; then
    echo "=== REACHED ok>=22 on run $i ==="
    break
  fi
done
echo "=== LOOP DONE ==="
