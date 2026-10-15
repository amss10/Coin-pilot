# Coin-pilot architecture

Coin-pilot is a **local-first** personal budgeting app (Flutter, iOS + Android) with optional AI features
powered by Claude through a thin Firebase proxy. All financial data lives in SQLite on the phone.

```
Flutter app ──(Firebase ID token + App Check)──► Cloud Functions proxy ──► Claude API
   │                                                │
   └─ SQLite (Drift) = source of truth              └─ Firestore: AI usage counters only
```

## Repository layout

| Path | What lives there |
|---|---|
| `app/` | Flutter app (`coin_pilot` package) |
| `backend/` | Firebase project config + `functions/` (TypeScript AI proxy) |
| `docs/` | This file, [AI design](ai-design.md), [AI contract](ai-contract.md), [privacy](privacy.md), [ADRs](adr/) |
| `.github/workflows/` | CI for the app and the functions |

## App layers (`app/lib/src`)

```
app/        composition root: bootstrap, root widget, router, shell, More screen
core/       cross-cutting infrastructure (no feature imports)
  config/     compile-time environment (--dart-define-from-file)
  database/   Drift database, tables, views, converters, seed
  finance/    shared enums used by tables and domain models
  money/      Money, Currency (ISO-4217 decimals), parsing, formatting, allocation
  time/       LocalDate, budget periods, recurrence, clock
  ids/        UUIDv7 id generator
  ai/         AiClient interface, Firebase callable + SSE chat clients, fake client, DTOs
  firebase/   Firebase bootstrap, auth/App Check token source, crash reporting
  platform/   app paths, file store, image normalisation
  security/   biometric/PIN app-lock service, privacy overlay
  notifications/, errors/, l10n/, theme/, widgets/
features/<feature>/
  domain/        pure Dart: models + repository interfaces + invariants
  data/          Drift implementations of the repositories
  application/   services, engines and Riverpod providers/notifiers
  presentation/  screens and widgets
```

### Dependency rules (enforced by `test/architecture/import_rules_test.dart`)
1. presentation → application → domain ← data.
2. `domain/` is pure Dart: no Flutter, Drift, Firebase or `dart:io`. It may use `core/money`, `core/time`, `core/finance`.
3. Only `data/` and `core/database` import Drift. Drift row classes are suffixed `Row` and never leave `data/`.
4. A feature may import another feature's `domain/` and `application/` only.
5. `core/` never imports `features/`; only `src/app/` imports everything.

### State management (Riverpod 3)
- Long-lived (`keepAlive`): database, repositories, AI client, router, clock, id generator.
- Everything else auto-disposes. Drift `watch()` queries are exposed as stream providers.
- **Retry policy:** Riverpod 3 retries failing providers by default. `core/errors/retry_policy.dart`
  disables retries for AI, validation and storage failures so a paid AI call is never replayed.

### Navigation (go_router)
- `/onboarding` sits outside the shell. The shell is a `StatefulShellRoute` with five tabs:
  Home · Transactions · Budgets · Pilot · More.
- `/capture` (Type · Speak · Scan · Manual) is a full-screen route on the root navigator.
- The app lock is an **overlay** in `MaterialApp.router(builder:)`, not a redirect, so navigation state survives locking.

## Data model
See the table list in `app/lib/src/core/database/tables/`. Key rules:
- Every table has `id` (UUIDv7 text), `created_at`, `updated_at`, nullable `deleted_at` (soft delete).
- Money = `amount_minor` (integer minor units) + `currency_code`. **Never a double.**
- Calendar dates are `YYYY-MM-DD` text (`LocalDate`).
- A transaction row is **one leg on one account**; transfers are two legs sharing `transfer_group_id`;
  the opening balance is a transaction with `entry_type = opening_balance`. Balances are always computed.
- Splits live in `transaction_splits` and must sum to the parent amount.
- The `categorized_amounts` view (unsplit standard rows + split lines, excluding transfers and deleted rows)
  feeds every budget and insight query.
- Budget limits are effective-dated (`budget_line_limits.effective_from`) so edits never rewrite history.
- AI chat messages are stored **verbatim** (`ai_messages.raw_json`) and are append-only.

### Migrations
`schemaVersion` starts at 1. Before changing any table: bump the version, run
`dart run drift_dev make-migrations`, implement the generated step, and keep the generated
schema tests passing. Never edit a published schema snapshot in `app/drift_schemas/`.

## AI
See [ai-design.md](ai-design.md) for behaviour and [ai-contract.md](ai-contract.md) for the wire format.
Core rule: **the AI never does arithmetic or invents amounts** — the app computes numbers; the AI classifies,
extracts and explains, and every output is validated before the user confirms it.
