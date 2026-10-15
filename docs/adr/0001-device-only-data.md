# ADR 0001: Device-only financial data

- Status: Accepted
- Date: 2026-10-15

## Context
Budget data is sensitive. A cloud database adds cost, compliance work and a breach surface, but enables
multi-device sync and shared budgets.

## Decision
All financial data lives in SQLite (Drift) on the phone. The only cloud component is a stateless AI proxy
that stores usage counters, never financial data. v1 has no sync.

## Consequences
- Strong privacy story; core features work offline.
- No multi-device access in v1. Data moves between phones via OS backup/device transfer or manual export.
- The schema stays sync-ready (UUIDv7 ids, `updated_at`, soft deletes) so opt-in sync can be added later.
- AI chat tools must run on the device (see ADR 0006).
