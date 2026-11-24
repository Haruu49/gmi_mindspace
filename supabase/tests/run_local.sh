#!/usr/bin/env bash
# Runs every migration plus the RLS test suites against a throwaway local
# PostgreSQL 16 instance (no Docker needed). Uses only fictional test users.
#
# Usage:  bash supabase/tests/run_local.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
PGBIN="${PGBIN:-/usr/lib/postgresql/16/bin}"
PORT="${PORT:-54330}"

cleanup() { "$PGBIN/pg_ctl" -D "$WORK/data" stop -m fast >/dev/null 2>&1 || true; rm -rf "$WORK"; }
trap cleanup EXIT

"$PGBIN/initdb" -D "$WORK/data" -U postgres -A trust >/dev/null
"$PGBIN/pg_ctl" -D "$WORK/data" -o "-k $WORK -p $PORT -c listen_addresses=''" -l "$WORK/pg.log" start >/dev/null
sleep 2

PSQL=(psql -h "$WORK" -p "$PORT" -U postgres -d postgres -v ON_ERROR_STOP=1 -q)
"${PSQL[@]}" -f "$ROOT/tests/supabase_shim.sql" 2>&1 | grep -v NOTICE || true
for f in "$ROOT"/migrations/*.sql; do
  echo "migrate: $(basename "$f")"
  "${PSQL[@]}" -f "$f" 2>&1 | grep -v NOTICE || true
done

OUT="$("${PSQL[@]}" -f "$ROOT/tests/rls_01_setup_and_privacy.sql" -f "$ROOT/tests/rls_02_roles_and_workflows.sql" -f "$ROOT/tests/rls_03_counsellor_signup.sql" 2>&1 || true)"
echo "$OUT" | grep -oE "(PASS|FAIL): .*" || true
PASSED=$(echo "$OUT" | grep -c "PASS:" || true)
if echo "$OUT" | grep -qE "FAIL:|ERROR:"; then
  echo "$OUT" | grep -E "ERROR:" || true
  echo "RLS TESTS FAILED ($PASSED passed before failure)"; exit 1
fi
echo "ALL RLS TESTS PASSED ($PASSED checks)"
