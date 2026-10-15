# AI design ("Pilot")

The wire format is specified in [ai-contract.md](ai-contract.md). This document explains the behaviour and the reasons.

## Principles
1. **AI is optional.** Every core flow works offline with AI switched off.
2. **The AI never does arithmetic or invents amounts.** Totals, forecasts, anomaly scores and budget options
   are computed on the device. Quick-add returns relative dates (`yesterday`, `3 days ago`) that the app resolves.
   Budget autopilot picks one of the options the app computed. Chat uses a `calculate` tool for what-if maths.
3. **Validate twice.** The proxy checks the model output against a schema, then against business rules
   (ids must come from the input, receipt arithmetic must add up, insights may only quote input numbers).
   The app validates again and shows a draft the user confirms.
4. **Minimal data.** Opaque ids, masked digits, no notes, no account numbers. Nothing financial is stored server-side.
5. **The server owns AI behaviour.** Prompts, tools, model, effort and limits are versioned in
   `backend/functions/src/prompts` and `config/`, so they change without an app release.

## Features
| Feature | Where it runs | Notes |
|---|---|---|
| Categorization | `features/categorization` | Local merchant rules first; only unmatched rows go to the AI, ≤50 per call. User corrections become rules. |
| Quick add (text/voice) | `features/capture` | On-device speech-to-text, then the same text parser. |
| Receipt scan | `features/capture` | Photo → JPEG ≤2000 px, EXIF stripped → extraction → prefilled form. |
| Insights | `features/insights` | Device computes stats; AI writes ≤6 ranked insights citing evidence refs. |
| Budget autopilot | `features/budgets` | Device computes tight/balanced/relaxed options; AI picks and explains. |
| Pilot chat | `features/pilot` | Tools run on the device against SQLite; the proxy streams the model. |

## Model settings
All tasks default to `claude-opus-5-5` with a per-task effort (`low` for categorize, quick add, receipts and chat;
`medium` for insights and budgets). Model and effort are server config; moving a task to a cheaper model
must pass the eval suite first. Server-side refusal fallback is enabled on every call.

## Pilot chat
- Tools execute on the device, so only the figures a question needs leave the phone.
- Claude binds its thinking blocks to the exact conversation prefix, so the history must be **append-only and
  replayed verbatim**. The app stores each message as the raw JSON string it received and never re-encodes it.
- The proxy signs the history (`historyMac`). The API accepts fabricated assistant turns, so the signature is what
  stops anyone using the proxy as a free general-purpose model.
- A conversation is pinned to a prompt version. Versions are immutable (a golden-hash test guards them);
  deprecated versions keep serving open chats ≥30 days, then retire (the app starts a new chat with a short carry-over).
- Limits: 6 tool rounds per user message (then `tool_choice: none`), 24 user messages, ~60K tokens per conversation.

## Quotas and cost
- ~250 credits per user per month (≤50 in the first 24 h) plus a hidden ≈$6/month cost cap; per-minute rate limits;
  a global daily spend breaker; per-task kill switches; an Anthropic Console spend limit on a dedicated workspace.
- Estimated ≈$2.75 per active user per month on `claude-opus-5-5` (range $1.80–5.00); chat is ~70%.

## Testing
- Proxy: vitest with a fake `LlmPort` (refusals, max_tokens, fallbacks, tool rounds, signature tampering).
- App: `FakeAiClient` drives every AI flow in dev and tests without network.
- Before changing prompts, schemas, model or effort: run the offline eval set (categorization, quick add,
  receipts, insights/budgets, chat) and block on >2-point accuracy drops or >15% cost/latency increases.
