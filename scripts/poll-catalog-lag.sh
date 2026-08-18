#!/usr/bin/env bash
# Poll HP-style catalog lag / backlog metrics during an XL ingest run.
# Requires: oc logged in, RHDH_NAMESPACE set, catalog Postgres reachable.
set -euo pipefail

NS="${RHDH_NAMESPACE:?Set RHDH_NAMESPACE}"
OUT_DIR="${1:-./results/current/metrics}"
INTERVAL_SEC="${POLL_INTERVAL_SEC:-120}"
CSV="${OUT_DIR}/catalog-lag.csv"

mkdir -p "${OUT_DIR}"
if [ ! -f "${CSV}" ]; then
  echo "timestamp_utc,refresh_total,unprocessed,processed,stitch_queue,final_total,overdue_unprocessed,avg_overdue_lag_s,p50_overdue_lag_s,p90_overdue_lag_s,max_overdue_lag_s,final_user,final_group,final_component,final_api" >"${CSV}"
fi

echo "Polling catalog lag every ${INTERVAL_SEC}s into ${CSV} (namespace=${NS})"

while true; do
  PGPOD=$(oc get pods -n "${NS}" -l postgres-operator.crunchydata.com/role=master -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
  if [ -z "${PGPOD}" ]; then
    echo "$(date -u +%FT%TZ) WARN: no postgres primary pod" >&2
    sleep "${INTERVAL_SEC}"
    continue
  fi

  ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  row=$(oc exec -n "${NS}" "${PGPOD}" -c database -- psql -U postgres -d backstage_plugin_catalog -t -A -F',' -c "
WITH base AS (
  SELECT
    count(*) AS refresh_total,
    count(*) FILTER (WHERE processed_entity IS NULL) AS unprocessed,
    count(*) FILTER (WHERE processed_entity IS NOT NULL) AS processed
  FROM refresh_state
),
lag AS (
  SELECT
    count(*) AS overdue_unprocessed,
    COALESCE(avg(EXTRACT(EPOCH FROM (now() - next_update_at))),0) AS avg_overdue_lag_s,
    COALESCE(percentile_cont(0.5) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM (now() - next_update_at))),0) AS p50_overdue_lag_s,
    COALESCE(percentile_cont(0.9) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM (now() - next_update_at))),0) AS p90_overdue_lag_s,
    COALESCE(max(EXTRACT(EPOCH FROM (now() - next_update_at))),0) AS max_overdue_lag_s
  FROM refresh_state
  WHERE processed_entity IS NULL AND next_update_at <= now()
),
queues AS (
  SELECT
    (SELECT count(*) FROM stitch_queue) AS stitch_queue,
    (SELECT count(*) FROM final_entities) AS final_total
),
finals AS (
  SELECT
    count(*) FILTER (WHERE entity_ref LIKE 'user:%') AS final_user,
    count(*) FILTER (WHERE entity_ref LIKE 'group:%') AS final_group,
    count(*) FILTER (WHERE entity_ref LIKE 'component:%') AS final_component,
    count(*) FILTER (WHERE entity_ref LIKE 'api:%') AS final_api
  FROM final_entities
)
SELECT
  b.refresh_total, b.unprocessed, b.processed,
  q.stitch_queue, q.final_total,
  l.overdue_unprocessed,
  round(l.avg_overdue_lag_s::numeric,1),
  round(l.p50_overdue_lag_s::numeric,1),
  round(l.p90_overdue_lag_s::numeric,1),
  round(l.max_overdue_lag_s::numeric,1),
  f.final_user, f.final_group, f.final_component, f.final_api
FROM base b, lag l, queues q, finals f;
" 2>/dev/null | tr -d '[:space:]')

  if [ -n "${row}" ]; then
    echo "${ts},${row}" | tee -a "${CSV}"
  else
    echo "${ts} WARN: query failed" >&2
  fi
  sleep "${INTERVAL_SEC}"
done
