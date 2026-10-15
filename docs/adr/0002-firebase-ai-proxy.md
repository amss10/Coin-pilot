# ADR 0002: Firebase-hosted AI proxy

- Status: Accepted
- Date: 2026-10-15

## Context
The Claude API key cannot ship inside the app. A public proxy can be abused to spend the AI budget unless callers
are attested, rate-limited and metered.

## Decision
Host the proxy on Firebase: 2nd-gen Cloud Functions (TypeScript, Node 22), Anonymous Auth (one identity per
install, used for quotas), App Check (Play Integrity / App Attest) to reject non-app callers, Firestore for usage
counters only, Secret Manager for `ANTHROPIC_API_KEY` and `HMAC_KEY`.
Structured tasks are callable functions; chat is an HTTP function streaming Server-Sent Events.

## Consequences
- App attestation and per-install quotas come almost for free.
- Requires the Blaze (pay-as-you-go) plan; local development uses the emulator with a `demo-` project.
- Play Integrity has daily quotas: App Check token TTL is raised to 6–12 h and a higher tier is requested before ~3k DAU.
- Firebase stores no financial data; the privacy policy must still name Firebase and Anthropic as processors.
