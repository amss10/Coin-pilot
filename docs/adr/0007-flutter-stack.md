# ADR 0007: Flutter stack — Riverpod 3, go_router, Drift, freezed, material_ui

- Status: Accepted
- Date: 2026-10-15

## Decision
- **Riverpod 3 + code generation** for state and dependency injection; riverpod_lint runs as an analyzer plugin.
  A global retry policy disables Riverpod's default automatic retry for AI, validation and storage failures.
- **go_router** with a `StatefulShellRoute` for the five tabs; one long-lived router refreshed via `refreshListenable`.
- **Drift** on SQLite (bundled through the sqlite3 build hook; no `*_flutter_libs` packages) with reactive queries
  and `make-migrations` schema snapshots from v1.
- **freezed + json_serializable** for immutable domain models and AI DTOs.
- **material_ui**: the SDK's built-in Material library is frozen and being deprecated.
- **very_good_analysis** lints; **mocktail** only at boundaries (AI client, notifications, auth).

## Consequences
- Generators share analyzer/build constraints and must be upgraded together.
- Generated files are not committed; CI runs `build_runner` before analysis and tests.
