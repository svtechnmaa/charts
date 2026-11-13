#!/bin/bash
# Check that icinga2 is feeding the Redis of its own pod: config present and heartbeat fresh.
# Icinga 2 writes its config into Redis only when the process starts. A Redis that restarted
# without its data stays without icinga:host until icinga2 itself restarts (Icinga Web /
# Grafana then show states without host names).
#
# Usage: redis-check.sh [strict|liveness]
#   strict   : Redis not answering => FAIL (startupProbe, manual checks)
#   liveness : Redis not answering => PASS (the redis container's own probe handles it,
#              a Redis outage must not restart icinga2 as well)
# The image has no redis-cli, so talk RESP over bash /dev/tcp.
MODE="${1:-liveness}"
HOSTKEY="${HOSTKEY:-icinga:host}"
REDIS_PORT="${REDIS_PORT:-6379}"
MAX_AGE_MS="${REDIS_CHECK_MAX_AGE_MS:-180000}"

resp=$(timeout 3 bash -c "exec 3<>/dev/tcp/127.0.0.1/${REDIS_PORT} &&
  printf 'PING\r\nHLEN ${HOSTKEY}\r\nXREVRANGE icinga:stats + - COUNT 1\r\nQUIT\r\n' >&3 &&
  cat <&3" 2>/dev/null | tr -d '\r')

if ! grep -q '^+PONG' <<<"$resp"; then
  [ "$MODE" = "liveness" ] && exit 0
  echo "redis not responding"; exit 1
fi

hosts=$(sed -n '2p' <<<"$resp" | tr -d ':')
[[ "$hosts" =~ ^[0-9]+$ ]] || hosts=0
last=$(grep -oE '^[0-9]{13}-[0-9]+$' <<<"$resp" | head -1 | cut -d- -f1)
now=$(date +%s%3N)

# 0 Hosts is expected while the shared zones.d cannot be loaded (e.g. Syncthing conflict files):
# the leader runs without zones.d (leader-no-content) and syncs nothing, so a follower without old
# config (new pod) has 0 Hosts too (follower-no-content). Restarting icinga2 cannot fix it, it would
# only loop. The election rewrites READY_FILE when it is fixed, so the check is back on then.
if [ "$hosts" -eq 0 ]; then
  read -r role _ 2>/dev/null < "${ELECTION_READY_FILE:-/tmp/icinga2-election/ready}"
  case "$role" in
    leader-no-content|follower-no-content) ;;
    *) echo "${HOSTKEY} empty in local Redis"; exit 1 ;;
  esac
fi
if [ -z "$last" ]; then echo "no icinga:stats heartbeat in local Redis"; exit 1; fi
age=$((now - last))
if [ "$age" -ge "$MAX_AGE_MS" ]; then echo "icinga:stats heartbeat stale ${age}ms"; exit 1; fi
exit 0
