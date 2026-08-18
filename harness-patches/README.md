# Harness patches for stock backstage-performance

Vendored changes not yet merged upstream. Apply with `scripts/apply-overlay.sh`.

## Contents

| Artifact | Purpose |
|----------|---------|
| `0001-harness-core.patch` | `deploy.sh`, `setup.sh`, `create_resource.sh`, app-config, API template |
| `scenarios/isolation/` | Run scripts and env presets for XL isolation tests |

## Patch targets

- `SKIP_GITHUB` — LDAP-only runs without GitHub secrets
- `LDAP_SCHEDULE_TIMEOUT` — avoid re-sync at 500k groups
- `PRE_LOAD_DB=false` location reuse
- IBM cluster: PGO skip, rhbk-operator bootstrap, stable Keycloak DB password
- GitHub token in app-config for private catalog locations
- Inline OpenAPI in API template

## Refreshing the patch

From a `backstage-performance` checkout with your local changes:

```bash
git diff origin/main -- \
  ci-scripts/rhdh-setup/deploy.sh \
  ci-scripts/setup.sh \
  ci-scripts/rhdh-setup/create_resource.sh \
  ci-scripts/rhdh-setup/template/backstage/app-config.yaml \
  ci-scripts/rhdh-setup/template/component/api.template \
  > harness-patches/0001-harness-core.patch
```

Verify before committing:

```bash
git worktree add /tmp/bp-test origin/main
cd /tmp/bp-test && git apply --check /path/to/0001-harness-core.patch
```

## Upstream base

Patch generated against `redhat-performance/backstage-performance` @ `274b6a6` (or current `origin/main` at time of vendoring). Re-apply may fail after upstream drift — refresh the patch or drop it once changes are merged.
