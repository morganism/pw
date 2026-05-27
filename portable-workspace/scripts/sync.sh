#!/usr/bin/env bash
# scripts/sync.sh — CLI sync helper for PortableWork
# Usage:
#   ./scripts/sync.sh push [workspace_id] [message]
#   ./scripts/sync.sh pull [workspace_id]
#   ./scripts/sync.sh status
set -euo pipefail

HOST="${PW_HOST:-https://localhost:4567}"
CMD="${1:-status}"
WS_ID="${2:-}"
MSG="${3:-chore: sync workspace state}"

GREEN='\033[0;32m'; RED='\033[0;31m'; BOLD='\033[1m'; RESET='\033[0m'

ok()  { echo -e "${GREEN}✓${RESET} $1"; }
err() { echo -e "${RED}✗${RESET} $1"; exit 1; }
h1()  { echo -e "\n${BOLD}$1${RESET}"; }

case "$CMD" in
  status)
    h1 "PortableWork Status"
    curl -sk "${HOST}/api/status" | python3 -m json.tool 2>/dev/null || \
    curl -sk "${HOST}/api/status"
    ;;

  push)
    [ -z "$WS_ID" ] && err "Usage: sync.sh push <workspace_id> [message]"
    h1 "Pushing workspace #${WS_ID}..."
    RESULT=$(curl -sk -X POST "${HOST}/sync/push/${WS_ID}" \
      -H 'Content-Type: application/json' \
      -d "{\"message\": \"${MSG}\"}")
    echo "$RESULT" | grep -q '"success":true' && \
      ok "Push successful: $(echo $RESULT | grep -o '"message":"[^"]*"' | head -1)" || \
      err "Push failed: $RESULT"
    ;;

  pull)
    [ -z "$WS_ID" ] && err "Usage: sync.sh pull <workspace_id>"
    h1 "Pulling workspace #${WS_ID}..."
    RESULT=$(curl -sk -X POST "${HOST}/sync/pull/${WS_ID}" \
      -H 'Content-Type: application/json')
    echo "$RESULT" | grep -q '"success":true' && \
      ok "Pull successful" || \
      err "Pull failed: $RESULT"
    ;;

  log)
    h1 "Sync Log"
    curl -sk "${HOST}/api/sync-log?limit=${WS_ID:-20}" | \
      python3 -c "
import json,sys
for e in json.load(sys.stdin):
    icon = '✓' if e['status']=='success' else '✗'
    print(f\"{icon} [{e['action'].upper():5}] WS#{e['workspace_id']} | {e['created_at']} | {e['message'][:80]}\")
" 2>/dev/null || curl -sk "${HOST}/api/sync-log"
    ;;

  *)
    echo "Usage: sync.sh {status|push|pull|log} [workspace_id] [message]"
    exit 1
    ;;
esac
