# AI proxy contract (v1)

The single source of truth for the JSON exchanged between the Flutter app (`app/lib/src/core/ai/`) and the
Cloud Functions proxy (`backend/functions/`). Change this file first, then both sides.

General rules:
- **Amounts** are decimal strings in the currency's own precision, e.g. `"-45.30"`, `"1200"` for JPY.
  The app converts to and from integer minor units. Negative means money out.
- **Dates** are local calendar dates `YYYY-MM-DD`. Months are `YYYY-MM`.
- **Ids** sent to the AI are short opaque ids (`t1`, `c12`, `a3`), mapped back on the device.
- Unknown fields are rejected (`.strict()` on every object).

## 1. Structured tasks (Firebase callable functions)

Functions: `categorizeTransactions`, `parseQuickAdd`, `extractReceipt`, `generateInsights`, `suggestBudgets`,
plus `getUsage` and `deleteMyData`. All require Firebase Auth (anonymous is fine) and App Check.

### 1.1 Envelope
Request `data`:
```json
{
  "v": 1,
  "idempotencyKey": "0199f0c2-...uuid",
  "appVersion": "0.1.0+1",
  "locale": "en-US",
  "currency": "USD",
  "timezone": "Africa/Cairo",
  "today": "2026-10-15",
  "payload": { }
}
```
Successful response:
```json
{
  "result": { },
  "credits": { "charged": 1, "remaining": 249, "resetsAt": "2026-11-01T00:00:00.000Z" },
  "meta": { "task": "parseQuickAdd", "promptVersion": "quick-add/v1", "model": "claude-opus-5-5" }
}
```
Errors are `HttpsError`s whose `details` always carry the app error code:
`{ "code": "<app code>", "retryAfterMs"?: number, "resetsAt"?: string, "issues"?: [{ "path": string, "message": string }] }`.

| App code | HttpsError code | App behaviour |
|---|---|---|
| `quota_exceeded` | `resource-exhausted` | Show reset date; no retry |
| `rate_limited` | `resource-exhausted` | Back off `retryAfterMs`, retry |
| `refusal` | `failed-precondition` | Neutral message; credits were refunded |
| `invalid_input` | `invalid-argument` | Don't retry; log `issues` |
| `upstream_unavailable` | `unavailable` | Retry up to 2× with backoff |
| `upgrade_required` | `failed-precondition` | Prompt app update |
| `unauthenticated` | `unauthenticated` | Refresh token once, then error |
| `internal` | `internal` | Generic error |

### 1.2 Shared payload pieces
```json
"categories": [{ "id": "c1", "name": "Groceries", "kind": "expense", "parent": "Food" }],
"accounts":   [{ "id": "a1", "name": "Visa", "type": "credit_card", "currency": "USD" }]
```
`kind`: `expense | income`. `parent`: string or null. Account `type`: `cash | checking | savings | credit_card | ewallet | other`.
Limits: categories ≤ 150 (name ≤ 40 chars), accounts ≤ 20.

### 1.3 `categorizeTransactions` (credits: ceil(n/10))
payload:
```json
{
  "categories": [ ],
  "corrections": [{ "text": "CARREFOUR MAADI", "categoryId": "c1" }],
  "transactions": [{ "id": "t1", "text": "CARREFOUR CITY STARS ****1234", "amount": "-45.30", "date": "2026-10-14", "accountType": "credit_card" }]
}
```
Limits: corrections ≤ 20; transactions 1–50, text ≤ 200 chars; total body ≤ 96 KB.
result:
```json
{ "results": [{ "id": "t1", "categoryId": "c1", "confidence": 0.92, "merchant": "Carrefour", "suggestRule": true }] }
```
Server guarantees: every input id exactly once; `categoryId` is an input category id or `null`; `confidence` in [0, 1].

### 1.4 `parseQuickAdd` (credits: 1)
payload:
```json
{ "text": "spent 45 on groceries at carrefour yesterday", "source": "typed", "categories": [ ], "accounts": [ ] }
```
`source`: `typed | voice`. Text 1–300 chars.
result:
```json
{
  "draft": {
    "kind": "expense",
    "amount": "45.00",
    "currency": "USD",
    "date": { "type": "yesterday", "daysAgo": null, "weekday": null, "date": null },
    "merchant": "Carrefour",
    "categoryId": "c1",
    "accountId": null,
    "toAccountId": null,
    "note": null
  },
  "confidence": 0.9,
  "needsClarification": false,
  "question": null
}
```
- `kind`: `expense | income | transfer`. `amount` is **as stated** (never computed), positive, or `null`.
- `date.type`: `today | yesterday | days_ago | last_weekday | absolute | unspecified`;
  `daysAgo` set for `days_ago`; `weekday` (`monday`…`sunday`) for `last_weekday`; `date` for `absolute`.
  **The app resolves the actual date** from `today`/`timezone`.
- ids are input ids or `null`.

### 1.5 `extractReceipt` (credits: 4)
payload:
```json
{ "image": { "mediaType": "image/jpeg", "base64": "<no data: prefix>" }, "categories": [ ] }
```
Limits: JPEG only, ≤ 2 MB decoded, long edge ≤ 2576 px (server reads the JPEG header). EXIF must already be stripped.
result:
```json
{
  "isReceipt": true,
  "legibility": "good",
  "merchant": "Carrefour",
  "date": "2026-10-14",
  "time": "18:32",
  "currency": "EGP",
  "subtotal": "100.00",
  "tax": "14.00",
  "tip": null,
  "total": "114.00",
  "lineItems": [{ "description": "Milk 1L", "quantity": "2", "amount": "50.00" }],
  "suggestedCategoryId": "c1",
  "checks": { "itemsMatchSubtotal": true, "totalsConsistent": true }
}
```
`legibility`: `good | partial | poor`. Discounts are negative line items. `checks` is **computed by the server**
(`null` when it can't be computed); if checks fail at effort `low` the server retries once at `medium`.

### 1.6 `generateInsights` (credits: 5)
payload (all numbers precomputed on device; every row has a unique `ref`):
```json
{
  "period": { "kind": "month", "start": "2026-10-01", "end": "2026-10-31" },
  "stats": {
    "monthOverMonth": [{ "ref": "mom:c1", "category": "Dining", "current": "320.00", "previous": "210.00", "deltaPct": "52.4" }],
    "anomalies":      [{ "ref": "anom:t9", "date": "2026-10-12", "merchant": "Apple", "category": "Shopping", "amount": "999.00", "typical": "120.00" }],
    "subscriptions":  [{ "ref": "sub:s1", "merchant": "Netflix", "amount": "15.99", "cadence": "monthly", "status": "price_up", "priceChangePct": "20.0" }],
    "budgetPace":     [{ "ref": "bud:c1", "category": "Groceries", "limit": "400.00", "spent": "310.00", "expectedByToday": "200.00", "status": "at_risk" }],
    "goals":          [{ "ref": "goal:g1", "name": "Laptop", "target": "1200.00", "saved": "450.00", "pct": "37.5", "onTrack": false }]
  }
}
```
Limits: monthOverMonth ≤ 40, anomalies ≤ 20, subscriptions ≤ 30, budgetPace ≤ 40, goals ≤ 10; body ≤ 64 KB.
`period.kind`: `week | month`. Subscription `status`: `new | active | price_up | missed`. Budget `status`: `on_track | at_risk | over`.
result:
```json
{ "insights": [{
  "kind": "spending_trend", "severity": "warning",
  "title": "Dining is up 52.4%", "body": "You spent 320.00 on dining vs 210.00 last month.",
  "evidenceRefs": ["mom:c1"],
  "action": { "type": "review_transactions", "targetRef": "mom:c1" }
}] }
```
`kind`: `spending_trend | anomaly | subscription | budget | goal | tip`; `severity`: `positive | info | warning | critical`;
`action.type`: `none | review_transactions | adjust_budget | review_subscription | open_goal`.
Server guarantees: ≤ 6 insights; every `evidenceRefs` entry and `targetRef` exists in the input; any insight that quotes
a number not present in the input stats is dropped.

### 1.7 `suggestBudgets` (credits: 5)
payload:
```json
{
  "preference": "balanced",
  "monthlyIncome": "5000.00",
  "lines": [{
    "ref": "c1", "category": "Groceries", "isFixed": false, "current": "400.00",
    "stats": { "monthsOfData": 4, "median": "380.00", "mean": "395.00", "min": "300.00", "max": "520.00", "lastMonth": "410.00" },
    "options": { "tight": "340.00", "balanced": "390.00", "relaxed": "450.00" }
  }]
}
```
`preference`: `save_more | balanced | flexible`. `monthlyIncome` and `current` may be `null`. Lines ≤ 60.
result:
```json
{ "lines": [{ "ref": "c1", "choice": "balanced", "amount": "390.00", "rationale": "Close to your typical month." }],
  "summary": "…" }
```
`choice`: `keep | tight | balanced | relaxed`. **`amount` is filled in by the server** from the chosen option
(`keep` with no current limit falls back to `balanced`).

### 1.8 `getUsage` (no credits)
payload `{}` → result `{ "creditsUsed": 12, "creditsLimit": 250, "remaining": 238, "resetsAt": "…" }`.

### 1.9 `deleteMyData` (no credits)
payload `{}` → deletes the caller's usage records and anonymous account. result `{ "deleted": true }`.

## 2. Pilot chat (HTTP function `chat`, Server-Sent Events)

`POST <functions base URL>/chat`
Headers: `Authorization: Bearer <Firebase ID token>`, `X-Firebase-AppCheck: <token>`,
`Content-Type: application/json`, `Accept: text/event-stream`.

Body:
```json
{
  "v": 1,
  "conversationId": "uuid",
  "promptVersion": null,
  "toolsetVersion": 1,
  "idempotencyKey": "uuid",
  "appVersion": "0.1.0+1",
  "historyMac": null,
  "messages": [ ]
}
```
- `messages` = every committed message **exactly as received earlier** (raw JSON, Anthropic `MessageParam` shape),
  followed by exactly **one** new user message (the "tail").
- `promptVersion` and `historyMac` are `null` only for the first request of a conversation (then `messages` is just the tail).
- `historyMac` = base64url(HMAC-SHA256(key, `uid` + "\n" + `conversationId` + "\n" + `promptVersion` + "\n" +
  hex(SHA-256(RFC 8785 canonical JSON of the prior messages array)))). Only the proxy can compute it.

Tail rules (everything else is rejected with `invalid_input`):
- **User text turn** (only when no tool call is pending): content = optional context block + one text block.
  - Context block: `{"type":"text","text":"<context today=\"2026-10-15\" tz=\"Africa/Cairo\" currency=\"USD\">…</context>"}`
    (≤ 8 KB; the first turn also lists categories and accounts inside it).
  - Question block: `{"type":"text","text":"How much did I spend on dining?"}` (1–2000 chars).
- **Tool results turn** (only when tool calls are pending): content = one `tool_result` block per pending `tool_use` id,
  `{"type":"tool_result","tool_use_id":"toolu_…","content":"<json string ≤ 8 KB>","is_error":false}`, total ≤ 32 KB.
- No images, no `system` role, no unknown fields.
- Caps: body ≤ 1 MB, ≤ 24 user text turns, ≈ 60K estimated tokens → `conversation_too_long`.

SSE events (`event: <name>` + `data: <json>`), plus a `: ping` comment every 15 s:

| Event | Data |
|---|---|
| `meta` | `{ "promptVersion": "chat/v1", "model": "claude-opus-5-5" }` |
| `text` | `{ "delta": "You spent " }` |
| `tool` | `{ "name": "get_spending_summary" }` (status line only) |
| `final` | `{ "append": [ MessageParam… ], "stopReason": "end_turn", "stopDetails": null, "pendingToolUses": [{ "id": "toolu_…", "name": "…", "input": { } }], "historyMac": "…", "usage": { "inputTokens": 0, "outputTokens": 0, "cacheReadTokens": 0, "cacheWriteTokens": 0 }, "credits": { "charged": 2, "remaining": 236, "resetsAt": "…" }, "servedBy": "claude-opus-5-5" }` |
| `error` | `{ "code": "<app code>", "message": "…", "retryAfterMs": null }` |

- `append` contains the user tail **and** the new assistant message(s), verbatim. The app stores each as a raw JSON string.
- `stopReason` `tool_use` → the app runs every pending tool and sends one tool-results turn.
- After 6 tool rounds in one user turn the proxy sends `tool_choice: none`, forcing an answer.
- `refusal` (after fallbacks) → `final` has no assistant message to commit; the app discards the user turn; credits refunded.
- Chat-only error codes: `prompt_version_retired` (HTTP 409), `conversation_too_long` (409).
- A user text turn costs 2 credits; tool-results turns cost 0.

### 2.1 Tools (executed on the device; toolset 1)
All inputs are required; no numeric bounds in schemas — the app clamps and reports clamping in a `notes` field.
Results are JSON strings ≤ 8 KB; amounts are decimal strings with a `currency` field.

| Tool | Input |
|---|---|
| `get_accounts` | `{}` |
| `get_spending_summary` | `date_from, date_to, flow (expense\|income), group_by (category\|merchant\|month\|week\|account), category_ids[], top_n` |
| `compare_periods` | `a_from, a_to, b_from, b_to, group_by (category\|merchant\|account), flow, top_n` |
| `search_transactions` | `date_from, date_to, query, category_ids[], min_abs_amount, max_abs_amount (0 = none), flow (expense\|income\|any), sort (date_desc\|amount_desc\|amount_asc), limit` |
| `get_budget_status` | `month (YYYY-MM), category_ids[]` |
| `list_subscriptions` | `status (active\|all), sort (amount_desc\|next_date)` |
| `get_cash_flow_forecast` | `horizon_days, account_ids[]` |
| `get_goal_progress` | `goal_ids[]` |
| `calculate` | `expression` (+ − × ÷, parentheses, decimals) |

Empty arrays mean "all".
