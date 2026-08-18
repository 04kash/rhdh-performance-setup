# rhdh-performance-setup

Thin runbook and env overlays for running the **combined XL ingest** scenario
(30k users / 500k groups / 35k Components / 35k APIs) on memory-constrained
OpenShift clusters.

This repo does **not** duplicate the [backstage-performance](https://github.com/redhat-performance/backstage-performance)
harness. It documents how we ran it, which env vars to use, and records results.

## vs official performance team preset

| | Official `large_scale_xl_compare_test` | This overlay |
|---|----------------------------------------|--------------|
| Entity counts | 30k / 500k / 35k / 35k | Same |
| Memory | 31Gi × 3 replicas | **8Gi × 1 replica** |
| Locust load test | Yes | **No** (ingest-only) |
| GitHub entities | Regenerated each deploy | **Pre-pushed, reused** |
| Orchestrator | Enabled | Disabled |

See [UPSTREAM.md](UPSTREAM.md) for what belongs in the main harness vs here.

## Prerequisites

1. **OpenShift cluster** with admin `oc` access (`export KUBECONFIG=...`)
2. **backstage-performance** checkout with isolation-scenario patches (see UPSTREAM.md)
3. **Secrets** (never commit these):
   - `quay.token` — image pull secret for Quay.io
   - `github.token`, `github.user`, `github.repo` — scratch repo for catalog YAML
4. **Node sizing** — workers with enough allocatable memory for 8Gi RHDH pod + Keycloak + LDAP + Postgres (~14Gi+ total on one node)

## Quick start

```bash
# 1. Clone both repos
git clone https://github.com/redhat-performance/backstage-performance.git
git clone https://github.com/04kash/rhdh-performance-setup.git

# 2. Apply harness patches (see UPSTREAM.md) or use a branch that includes them

# 3. Install env overlay
cd rhdh-performance-setup
chmod +x scripts/*.sh
./scripts/apply-overlay.sh ../backstage-performance

# 4. Local secrets (gitignored)
cp env/.setenv.local.example ../backstage-performance/.setenv.local
# Edit paths and credentials in .setenv.local

# 5. Choose a dedicated namespace
export RHDH_NAMESPACE=rhdh-performance-xl

# 6. One-time: push 70k catalog entities to your scratch GitHub repo
cd ../backstage-performance
./scenarios/isolation/push-github-xl.sh

# 7. Run combined XL (clean deploy + ingest watch)
./scenarios/isolation/run.sh combined-xl-reuse-github
```

`run.sh` runs `make clean-all` then `ci-scripts/setup.sh`. With `PRE_LOAD_DB=false`,
it restores catalog location URLs from `combined-xl-locations.yaml` in the harness
(generated when you ran `push-github-xl.sh`).

## Watch during ingest

```bash
export RHDH_NAMESPACE=rhdh-performance-xl

oc get pods -n "$RHDH_NAMESPACE" -w
oc logs -n "$RHDH_NAMESPACE" -l app.kubernetes.io/name=developer-hub -f

# HP-style processing lag / backlog (optional, background)
./scripts/poll-catalog-lag.sh ./results/current/metrics &
```

Expect **multi-hour** first ingest: LDAP commit + stitch backlog is normal.
504s on health checks during LDAP read are event-loop blocking, not necessarily OOM.

## Recorded results

| Run | Verdict | Notes |
|-----|---------|-------|
| [2026-08-14 IBM QE](results/combined-xl-ibm-2026-08-14/) | **PASS** | 8Gi / 1 replica, ~3.8h to searchable, 0 OOM |

Do not commit full poller CSVs or pod logs — keep those in ticket attachments or object storage.

## IBM QE cluster notes

Shared perf cluster (`c104-e-us-east`). Typical workarounds baked into harness patches:

- Skip namespace-local PGO if cluster-wide operator exists in `openshift-operators`
- Bootstrap `rhbk-operator` from another namespace when catalog subscription is unavailable
- Set `KEYCLOAK_DB_PASSWORD` to a stable value across `clean-all` (via `.setenv.local`)

OpenShift console URL is cluster-specific — use `oc whoami --show-console` after login.

## Repository layout

```
env/           # Scenario env overlays (no secrets)
scripts/       # Metrics poller, apply-overlay helper
results/       # Summaries and analysis only (no raw logs)
UPSTREAM.md    # What to contribute back to backstage-performance
```

## Security

- Never commit tokens, kubeconfigs, or `.setenv.local`
- Use a dedicated namespace per run
- Rotate any credentials that were ever pasted into chat or logs
