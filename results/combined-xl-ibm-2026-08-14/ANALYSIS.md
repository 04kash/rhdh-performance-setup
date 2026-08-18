# Combined XL (reuse GitHub) — IBM QE run

**Recorded:** 2026-08-14  
**Cluster:** IBM QE shared perf (`c104-e-us-east`)  
**Preset:** 8Gi pod limit, 1 replica, `combined-xl-reuse-github`

## Verdict: PASS

| Track | Outcome |
|-------|---------|
| LDAP 30k users / 500k groups | PASS — 30001 / 500001 in `final_entities`, `stitch_queue=0` |
| GitHub 35k Component + 35k API | PASS — both at target |
| OOM / heap | PASS — 0 restarts, 0 heap OOM, ~2.3 Gi at completion |

## Timeline (UTC)

| Event | Time |
|-------|------|
| Backend start | 16:39:20 |
| LDAP read start (observed) | ~16:40:37 |
| LDAP users+groups commit | 17:35:58 |
| All targets stitched / searchable | ~20:27 (~3.8h from boot) |

## HP-recommended metrics

| Measurement | Value |
|-------------|------:|
| Peak processing lag (avg overdue) | ~7479 s (~2.1 h) |
| Peak `stitch_queue` | ~281908 |
| Peak unprocessed | ~233260 |
| Final lag / stitch_queue | 0 / 0 |
| Boot → all targets stitched | ~3.8 h |
| Memory at completion | ~2337 Mi (8Gi limit, 6144 Mi heap) |

### Final counts

| Kind | Target | Final |
|------|-------:|------:|
| User | 30001 | 30001 |
| Group | 500001 | 500001 |
| Component | 35000 | 35000 |
| API | 35000 | 35000 |

## Notes

- Mid-run API count at 30k was stitch backlog, not ingest failure.
- GitHub token must be enabled in `app-config.yaml` for private scratch repo locations.
- Official 31Gi × 3 preset does not schedule on this cluster’s worker size; this 8Gi variant is the adapted equivalent workload.

See `summary.json` in this directory for machine-readable metrics.
