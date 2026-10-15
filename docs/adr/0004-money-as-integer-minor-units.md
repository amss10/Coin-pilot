# ADR 0004: Money as integer minor units

- Status: Accepted
- Date: 2026-10-15

## Context
Binary floating point cannot represent most decimal amounts exactly; rounding drift corrupts balances and splits.

## Decision
Amounts are stored and computed as `int` minor units plus an ISO-4217 code (`Money`). A currency table defines
decimals (JPY 0, KWD 3, most 2). Parsing user input and AI output goes straight from decimal strings to minor units.
Splits use largest-remainder allocation so parts always sum exactly. Doubles are used only to format for display.

## Consequences
- Exact balances and split sums, enforced by tests.
- The AI wire format uses decimal strings in the currency's precision (see the AI contract).
