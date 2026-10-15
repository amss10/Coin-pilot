# ADR 0005: No separate database encryption in v1

- Status: Accepted
- Date: 2026-10-15

## Context
SQLCipher-style encryption needs a key. A key that lives only in the Android Keystore or a device-only iOS Keychain
item does not move to a new phone, so a restored backup would be unreadable — and for a device-only app, backup and
device transfer are how data survives a phone change. The old `sqlcipher_flutter_libs` package is end-of-life;
encryption now goes through the sqlite3 build hook (SQLite3MultipleCiphers).

## Decision
v1 relies on OS encryption at rest (Android file-based encryption, iOS Data Protection), app sandboxing, an optional
biometric/PIN app lock, and explicit backup rules (database only in end-to-end-encrypted cloud backups).
`core/database/connection.dart` keeps the `setup` hook where `PRAGMA key` will go.

## Consequences
- Phone migration just works in v1.
- v1.x will add SQLite3MultipleCiphers with a random key protected by a user recovery passphrase, plus encrypted
  export files, and `PRAGMA rekey` the existing database.
