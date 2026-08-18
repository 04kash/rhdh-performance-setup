# Catalog location URLs

Do **not** commit generated location lists here unless they point at intentionally
public fixture repos.

## How to produce locations

From your `backstage-performance` checkout (with GitHub secrets configured):

```bash
./scenarios/isolation/push-github-xl.sh
```

This pushes 35k Component + 35k API YAML shards to your scratch GitHub repo and
builds `.tmp/locations.yaml` (140 location entries).

Copy the stable list into the harness for reuse across `clean-all`:

```bash
cp .tmp/locations.yaml scenarios/isolation/combined-xl-locations.yaml
```

`run.sh combined-xl-reuse-github` restores that file after `make clean-all` when
`PRE_LOAD_DB=false`.

## Why not in git

Location URLs embed your org, repo, and branch/commit SHAs. Keep them local or in
your scratch repo — not in a shared runbook repo.
