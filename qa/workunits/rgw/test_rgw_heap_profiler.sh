#!/usr/bin/env bash
# -*- mode:shell-script; tab-width:8; sh-basic-offset:2; indent-tabs-mode:nil -*-
# Test RGW tcmalloc heap profiler (same as osd/mon/mds heap commands).
# Run after vstart.sh or in teuthology with at least one RGW.
# Requires: ceph in PATH, cluster with RGW running.

set -e

# SUDO for tell commands when needed (set SUDO= to skip sudo)
SUDO=${SUDO:-sudo}
SCRIPT_DIR=$(dirname $0)

if ! command -v ceph >/dev/null 2>&1; then
  echo "ceph not in PATH; run this script from a vstart or teuthology environment."
  exit 0
fi

# Find one running RGW daemon name (e.g. client.rgw.0 or client.rgw.foo)
get_rgw_daemon() {
  if [ -n "$RGW_ID" ]; then
    echo "client.rgw.$RGW_ID"
    return
  fi
  local name
  name=$(ceph status -f json 2>/dev/null | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    serv = d.get('services', {}) or {}
    rgw = serv.get('rgw') or []
    if rgw:
        print('client.rgw.' + rgw[0])
    else:
        sys.exit(1)
except Exception:
    sys.exit(1)
" 2>/dev/null) && echo "$name" && return
  echo "client.rgw.0"
}

RGW_DAEMON=$(get_rgw_daemon)
echo "Using RGW daemon: $RGW_DAEMON"

# Test heap stats (does not require profiler running)
echo "--- heap stats ---"
set +e
$SUDO ceph tell "$RGW_DAEMON" heap stats 2>&1 | tee /tmp/rgw_heap_stats.$$
out=$?
set -e
if [ $out -ne 0 ]; then
  if grep -q "not using tcmalloc\|tcmalloc not enabled\|unable to get value" /tmp/rgw_heap_stats.$$; then
    echo "RGW heap profiler not available (tcmalloc not in use or command not supported); skip."
    rm -f /tmp/rgw_heap_stats.$$
    exit 0
  fi
  cat /tmp/rgw_heap_stats.$$
  rm -f /tmp/rgw_heap_stats.$$
  exit $out
fi
if ! grep -q "tcmalloc heap stats\|MALLOC:" /tmp/rgw_heap_stats.$$; then
  echo "Unexpected output from heap stats:"
  cat /tmp/rgw_heap_stats.$$
  rm -f /tmp/rgw_heap_stats.$$
  exit 1
fi
echo "heap stats OK"
rm -f /tmp/rgw_heap_stats.$$

# Optional: start profiler, dump, stop, release (can be noisy)
echo "--- heap start_profiler ---"
$SUDO ceph tell "$RGW_DAEMON" heap start_profiler 2>&1 || true
echo "--- heap dump ---"
$SUDO ceph tell "$RGW_DAEMON" heap dump 2>&1 || true
echo "--- heap stop_profiler ---"
$SUDO ceph tell "$RGW_DAEMON" heap stop_profiler 2>&1 || true
echo "--- heap release ---"
$SUDO ceph tell "$RGW_DAEMON" heap release 2>&1 || true

echo "RGW heap profiler test passed."
exit 0
