# Harness relationship

This repo is a **standalone overlay** on stock
[backstage-performance](https://github.com/redhat-performance/backstage-performance).
It is not intended for upstream contribution.

## What `apply-overlay.sh` does

1. Applies `harness-patches/0001-harness-core.patch` to a clean harness checkout
2. Copies `harness-patches/scenarios/isolation/` into the harness
3. Installs `env/combined-xl-reuse-github.env`

## What the patch changes

| Change | Harness path | Why |
|--------|--------------|-----|
| `SKIP_GITHUB` | `ci-scripts/setup.sh`, `deploy.sh` | LDAP-only runs without GitHub secrets |
| `LDAP_SCHEDULE_TIMEOUT` | `deploy.sh` | Default PT50M retriggers sync at 500k groups |
| `PRE_LOAD_DB=false` location reuse | `deploy.sh`, `scenarios/isolation/run.sh` | Avoid re-pushing 70k entities every deploy |
| Cluster-wide PGO skip | `deploy.sh` | Shared clusters may already have PGO |
| `rhbk-operator` bootstrap fallback | `deploy.sh` | Missing catalog subscription on some clusters |
| Stable `KEYCLOAK_DB_PASSWORD` | `deploy.sh` | Random password breaks resume after PVC wipe |
| GitHub `integrations.github.token` | `template/backstage/app-config.yaml` | Private repo locations need token |
| Inline OpenAPI in API template | `template/component/api.template` | Remote `$text` fetch fails at scale |

## Keep only in this repo

| Artifact | Path | Reason |
|----------|------|--------|
| Runbook | `README.md` | How we run combined XL |
| HP scale notes | `docs/hp.md` | Metrics background |
| 8Gi env preset | `env/combined-xl-reuse-github.env` | Differs from official 31Gi×3 |
| Secrets template | `env/.setenv.local.example` | Paths vary per machine |
| Apply helper | `scripts/apply-overlay.sh` | Convenience |
| Result summaries | `results/*/` | Historical record |
| Patch + isolation scripts | `harness-patches/` | Required for stock harness |

## Do not copy into this repo

- Full `deploy.sh` / `setup.sh` (keep as a patch against a known harness base)
- Helm/OLM templates wholesale
- Ladder results, CSVs, logs
- `combined-xl-locations.yaml` (generated per scratch GitHub repo)

## Official perf team reference

In stock `backstage-performance`:

- `ci-scripts/release-tests.sh` → `large_scale_xl_compare_test()` — 31Gi × 3, includes Locust

Our `combined-xl.env` matches that sizing; `combined-xl-reuse-github.env` is the small-cluster variant.
