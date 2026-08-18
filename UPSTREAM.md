# Upstream vs overlay — file ownership

Use this when deciding what to **PR into backstage-performance** vs keep in this repo.

## Contribute upstream (general value)

These fixes apply to any large LDAP / IBM OpenShift run, not one person’s namespace.

| Change | Harness path | Why upstream |
|--------|--------------|--------------|
| `SKIP_GITHUB` for LDAP-only runs | `ci-scripts/setup.sh`, `deploy.sh` | Isolation testing without GitHub secrets |
| `LDAP_SCHEDULE_TIMEOUT` env → app-config | `deploy.sh` | Default PT50M retriggers sync at 500k groups |
| `PRE_LOAD_DB=false` location reuse | `deploy.sh`, `scenarios/isolation/run.sh` | Avoid re-pushing 70k entities every deploy |
| Cluster-wide PGO skip | `deploy.sh` | IBM/shared clusters already have PGO |
| `rhbk-operator` bootstrap fallback | `deploy.sh` | Missing catalog subscription on some clusters |
| Stable `KEYCLOAK_DB_PASSWORD` | `deploy.sh` | Random password breaks resume after PVC wipe |
| GitHub `integrations.github.token` | `template/backstage/app-config.yaml` | Private repo locations need token |
| Inline OpenAPI in API template | `template/component/api.template` | Remote `$text` fetch fails at scale |
| Isolation scenarios + ladder | `scenarios/isolation/*` | LDAP vs GitHub vs combined attribution |
| Catalog lag poller | `scenarios/isolation/poll-catalog-lag.sh` | HP-recommended metrics |

**Suggested PR title:** `feat(isolation): XL LDAP ingest on constrained clusters`

## Keep in this repo only (thin overlay)

| Artifact | Path here | Reason |
|----------|-----------|--------|
| Runbook + comparison table | `README.md` | Team-specific narrative |
| 8Gi env preset | `env/combined-xl-reuse-github.env` | Differs from official 31Gi×3 |
| Secrets template | `env/.setenv.local.example` | Paths vary per machine |
| Apply helper | `scripts/apply-overlay.sh` | Convenience |
| Result summaries | `results/*/` | Historical record, no huge CSVs |
| Cluster-specific notes | `README.md` § IBM QE | Shared cluster quirks |

## Do not duplicate upstream

Avoid copying into this repo:

- `ci-scripts/rhdh-setup/deploy.sh` (full file)
- `ci-scripts/setup.sh`
- Helm/OLM templates
- `Makefile`, Locust scenarios, CI config

Pin a **commit SHA or branch** in your run notes instead:

```bash
cd backstage-performance
git checkout <branch-or-sha>   # e.g. isolation-xl branch
```

## Official perf team reference

In `backstage-performance`:

- `ci-scripts/release-tests.sh` → `large_scale_xl_compare_test()`
- `scenarios/isolation/combined-xl.env` — full 31Gi × 3 preset (needs large nodes)

## GitHub catalog locations

After `push-github-xl.sh`, the harness writes:

- `.tmp/locations.yaml` (ephemeral)
- `scenarios/isolation/combined-xl-locations.yaml` (if saved manually)

This overlay repo does **not** ship the 140 URL list — it is tied to your scratch
repo branches/commits. Regenerate locally; do not commit org-specific URLs unless
they are intentionally public fixtures.
