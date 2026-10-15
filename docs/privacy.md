# Privacy model

## Where data lives
| Data | Location | Leaves the phone? |
|---|---|---|
| Accounts, transactions, budgets, goals, rules, settings | SQLite in Application Support | Only in OS backups and user exports |
| Receipt photos | `receipts/` under Application Support | Only when the user scans one with AI on (sent once for extraction) |
| AI chat history | SQLite (`ai_messages`) | Replayed to the proxy on each chat turn (not stored server-side) |
| AI usage counters | Firestore `usage/{uid}` | Server-side by design (no financial data) |

## What is sent to the AI (only when AI is switched on)
- **Categorization:** short ids, payee text with long digit runs masked, signed amount, date, account type,
  category names, a few of the user's past corrections.
- **Quick add:** the typed or transcribed sentence, category and account names.
- **Receipt scan:** the photo, re-encoded as JPEG with EXIF metadata removed.
- **Insights / budget autopilot:** aggregated statistics only — no individual transaction list.
- **Chat:** the user's messages and the results of the on-device tools the assistant asked for.

Never sent: notes, account numbers, emails, phone numbers, IBANs (masked or stripped before sending).
Requests are processed by Anthropic (Claude) through our proxy; the proxy logs metadata only
(hashed user id, task, model, token counts, latency, outcome) — never request or response content.

## Protection at rest
- The OS encrypts app storage (Android file-based encryption, iOS Data Protection) and sandboxes it.
- The database is **not** separately encrypted in v1: a device-bound key would make data unreadable after a
  phone migration, which is how a device-only app's data survives. `core/database/connection.dart` keeps a seam for
  SQLite3MultipleCiphers with a user recovery passphrase (planned v1.x).
- Optional app lock (biometrics / device PIN) with background timeout and an app-switcher privacy blur.

## Backups
- Android Auto Backup includes the database only when the backup is end-to-end encrypted
  (`disableIfNoEncryptionCapabilities`), plus device-to-device transfer. Receipt photos are excluded from cloud
  backup (25 MB cap) but included in device transfer. iOS backs up Application Support.
- Manual export (CSV/JSON) is always available.

## User controls
- AI is opt-in, with a per-feature switch; turning it off leaves the app fully usable.
- **Delete all data** wipes the local database and files, the anonymous Firebase account and the usage records.
- Crash reporting is opt-in. There is no analytics SDK.

## Store disclosures (draft)
Play Data Safety / App Store privacy labels: financial info and photos are processed on-device and, when the user
uses AI features, sent to our AI processor (Anthropic) for that request only; not sold; not used for tracking;
no server-side storage of financial data.
