# HP Backstage scale talk — cleaned notes

Condensed technical notes from Damon Caswell’s (HP) Backstage Con talk on large-scale
catalog ingestion. Original was a raw video transcript (`hp-talk.md`); this file keeps
the engineering content only.

**Scope:** hundreds of thousands → millions of entities from large external asset sources.

---

## Problem (two parts)

### 1. Ingestion does not scale with default patterns

| Approach | What goes wrong at scale |
|----------|--------------------------|
| Catalog processors emitting Locations → entities | Slow; little scheduling control; catalog polluted with synthetic Locations; orphans linger |
| Entity providers (full mutation) | Better for ingest + orphan cleanup, but a full mutation of ~200k entities into one array hits **Node.js heap OOM** |
| Workarounds | Artificial provider splits; raise heap — Band-Aids; catalogs keep growing |

Additional pain at hundreds of thousands / millions:

- Multi-pod DB concurrency (ingest + preprocess + postprocess fighting Postgres)
- Time from “written to DB” → “searchable” can be **hours**, worst case **days**

### 2. Processing loops are the backlog

Even after entities land in the DB, each one must pass through Backstage’s processing loop
before it is searchable (`refresh_state` → process → stitch → `final_entities`).

**Root cause measured by HP:** asynchronous HTTP (and similar I/O) inside pre/post
processors.

Example: a 500 ms HTTP GET per entity, with a 50k backlog and 4 pods, adds ~30 minutes
of wait for entities at the back of the queue — and the queue keeps refilling.

---

## Solution (two parts)

### Part 1 — Incremental entity providers

Custom provider (built with Backstage community help) that:

- Ingests large sources in **configurable chunks** (paging)
- **Pauses between bursts** (rate limits, e.g. GitHub)
- Supports backoff / retry on source errors
- Configurable schedule (frequency, burst length, rest between full runs)
- Admin REST endpoints to start / stop / pause / reset providers

**DB side tables (separate schema):**

1. Ingestions — status of a running provider
2. Ingestion marks — cursor / page position
3. Ingestion mark entities — track seen entities so orphans can be cleaned like a full mutation

**Requirements / limits:**

- Source must **paginate**
- Extra Postgres storage for tracking tables
- **No stateful APIs** (e.g. LDAP paged cookies scoped to a connection/session) when multiple
  replicas may pick up the next chunk — sessions don’t transfer

This solved flooding the catalog with one giant mutation. It did **not** alone make
entities searchable quickly.

### Part 2 — Optimize processing loops

Rule HP adopted: **ban async I/O from catalog processors.**

1. Front-load all HTTP / remote lookups into the **entity provider**
2. Attach that data on the entity as **temporary fields** for the processor
3. Processors run **synchronously** (emit relations / side effects from already-present data)
4. Strip temporary fields after emit

Ugly side effects they accepted: rewrite providers, strip processors, extend schemas with
transient fields that were never meant to live permanently on the entity.

**Results they reported (Grafana on `refresh_state` lag):**

| Environment / era | Processing lag (scheduled → processed) |
|-------------------|------------------------------------------|
| Earlier production pain | ~4.7 hours (worst: >1 day) |
| After change (prod) | ~20 minutes (~92% reduction) |
| Dev (further refinements) | ~15 minutes |
| Best seen | ~7 minutes |

Primary metric: average discrepancy between `next_update_at` (due) and when the entity
actually passes through the processing loop.

---

## Metrics to record (HP’s recommendation)

Use these when validating large ingest (this repo’s `scripts/poll-catalog-lag.sh` and
`results/*/ANALYSIS.md` follow the same ideas):

| Measurement | What it means |
|-------------|----------------|
| **Processing lag** | `now − next_update_at` for overdue unprocessed rows in `refresh_state` |
| **Backlog** | Unprocessed count + `stitch_queue` depth |
| **Time to searchable** | Wall clock from ingest commit → entity present in `final_entities` |
| **Heap OOM / restarts** | Full-mutation / memory failure mode |

Ingest commit ≠ searchable. Lag and stitch queue are the UX delay.

---

## Lessons HP called out

1. Default “emit Locations then process” advice does not scale to day-700 catalogs
2. Design for two-years-from-now entity counts, not the easiest zero-to-demo path
3. Backstage *can* ingest at this scale with the right provider + processor discipline
4. Incremental providers were planned for open source (as of the talk)

---

## Relevance to this repo

Our combined XL run (30k users / 500k groups / 70k catalog) used a **full LDAP mutation**
(not HP’s incremental provider — LDAP is stateful). We still hit the same backlog shape:

- Peak stitch queue ~282k
- Peak processing lag ~2.1 h
- Recovered to lag ≈ 0 with all targets searchable in ~3.8 h
- 0 heap OOM on 8Gi / 6Gi heap

See [results/combined-xl-ibm-2026-08-14/ANALYSIS.md](results/combined-xl-ibm-2026-08-14/ANALYSIS.md).
