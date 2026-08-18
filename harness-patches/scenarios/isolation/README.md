# Isolation scenarios

Run LDAP, GitHub catalog, or combined XL ingest in isolation.

**Requires:** `apply-overlay.sh` has patched stock `backstage-performance` and installed these files.

## Combined XL on small clusters (primary use case)

```bash
chmod +x scenarios/isolation/run.sh scenarios/isolation/push-github-xl.sh

# One-time: push 70k entities to your scratch GitHub repo
./scenarios/isolation/push-github-xl.sh
cp .tmp/locations.yaml scenarios/isolation/combined-xl-locations.yaml

# Deploy + ingest
export RHDH_NAMESPACE=rhdh-performance-xl
./scenarios/isolation/run.sh combined-xl-reuse-github
```

`combined-xl-locations.yaml` is **not** shipped in git (org/repo specific). Generate locally after `push-github-xl.sh`.

## Other scenarios

| Scenario | Env file | Notes |
|----------|----------|-------|
| LDAP only | `ldap-xl.env` | Needs ~31Gi nodes, `SKIP_GITHUB=true` |
| GitHub only | `github-xl.env` | 70k catalog, tiny LDAP |
| Full XL (official sizing) | `combined-xl.env` | 31Gi × 3 replicas |

## Timeouts

| Variable | combined-xl-reuse-github | combined-xl |
|----------|--------------------------|-------------|
| `LDAP_SCHEDULE_TIMEOUT` | PT6H | PT10H |
| `ENSURE_CATALOG_POPULATION_TIMEOUT` | 25200s | 43200s |

Stock harness default `PT50M` LDAP timeout retriggers sync before 500k groups finish.
