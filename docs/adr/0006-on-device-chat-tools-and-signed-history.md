# ADR 0006: On-device chat tools and a signed, append-only history

- Status: Accepted
- Date: 2026-10-15

## Context
Pilot chat must answer questions about data that only exists on the phone. Claude binds each thinking block to
the exact conversation prefix (system prompt, tools, every earlier message): for accounts created on or after
2026-08-31, editing earlier turns makes the API reject the request. The API also accepts assistant turns written
by the client, which would let a modified app use the proxy as a general-purpose model.

## Decision
- The proxy streams the model; when it asks for tools, the **app** runs them read-only against SQLite and sends
  all results back in one message. At most 6 tool rounds per user message.
- The app stores every message as the raw JSON string it received and replays it byte-for-byte; history is append-only.
- Each conversation is pinned to an immutable prompt version (system prompt + tools).
- The proxy returns `historyMac` (HMAC over uid, conversation, prompt version and the canonical history) and
  verifies it on every request, so history cannot be forged or edited.

## Consequences
- Only the figures a question needs leave the phone.
- "Edit and resend" starts a new conversation; long chats end with a carry-over into a new one.
- `prefix_mismatch_behavior` is `"error"` in CI/staging and `"drop_block"` in production with alerting.
