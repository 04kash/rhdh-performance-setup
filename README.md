# rhdh-performance-setup

Thin runbook and env overlays for running the **combined XL ingest** scenario
(30k users / 500k groups / 35k Components / 35k APIs) on memory-constrained
OpenShift clusters.

This repo holds harness patches, isolation scenarios, env overlays, and recorded
results for use with stock
[backstage-performance](https://github.com/redhat-performance/backstage-performance).
It is maintained separately — not as an upstream contribution.

## vs official performance team preset

| | Official `large_scale_xl_compare_test` | This overlay |
|---|----------------------------------------|--------------|
| Entity counts | 30k / 500k / 35k / 35k | Same |
| Memory | 31Gi × 3 replicas | **8Gi × 1 replica** |
| Locust load test | Yes | **No** (ingest-only) |
| GitHub entities | Regenerated each deploy | **Pre-pushed, reused** |
| Orchestrator | Enabled | Disabled |

See [HARNESS.md](HARNESS.md) for what the patch changes.

Background on why we measure processing lag / stitch backlog:
[docs/hp.md](docs/hp.md) (cleaned notes from HP’s Backstage scale talk).

## Prerequisites

1. **OpenShift cluster** with admin `oc` access (`export KUBECONFIG=...`)
2. **backstage-performance** checkout (stock `main` — patches applied by this repo)
3. **Secrets** (never commit these):
   - `quay.token` — image pull secret for Quay.io
   - `github.token`, `github.user`, `github.repo` — scratch repo for catalog YAML
4. **Node sizing** — workers with enough allocatable memory for 8Gi RHDH pod + Keycloak + LDAP + Postgres (~14Gi+ total on one node)

## Quick start

```bash
# 1. Clone both repos
git clone https://github.com/redhat-performance/backstage-performance.git
git clone https://github.com/04kash/rhdh-performance-setup.git

# 2. Apply harness patch + isolation scenarios
cd rhdh-performance-setup
chmod +x scripts/*.sh harness-patches/scenarios/isolation/*.sh
./scripts/apply-overlay.sh ../backstage-performance

# 3. Local secrets (gitignored)
cp env/.setenv.local.example ../backstage-performance/.setenv.local
# Edit paths and credentials in .setenv.local

# 4. Choose a dedicated namespace
export RHDH_NAMESPACE=rhdh-performance-xl

# 5. One-time: push 70k catalog entities to your scratch GitHub repo
cd ../backstage-performance
./scenarios/isolation/push-github-xl.sh
cp .tmp/locations.yaml scenarios/isolation/combined-xl-locations.yaml

# 6. Run combined XL (clean deploy + ingest watch)
./scenarios/isolation/run.sh combined-xl-reuse-github
```

`apply-overlay.sh` applies `harness-patches/0001-harness-core.patch` to stock
`deploy.sh` / `setup.sh` / templates, then copies `scenarios/isolation/`.

`run.sh` runs `make clean-all` then `ci-scripts/setup.sh`. With `PRE_LOAD_DB=false`,
it restores `combined-xl-locations.yaml` after clean-all (you generate this locally;
it is not committed — see `locations/README.md`).

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
docs/              # Background notes (e.g. HP scale talk)
harness-patches/   # Patch + scenarios/isolation scripts
env/               # Scenario env overlays (no secrets)
scripts/           # apply-overlay, metrics poller
results/           # Summaries and analysis only (no raw logs)
HARNESS.md         # What the patch changes vs stock harness
```

## Security

- Never commit tokens, kubeconfigs, or `.setenv.local`
- Use a dedicated namespace per run
- Rotate any credentials that were ever pasted into chat or logs
