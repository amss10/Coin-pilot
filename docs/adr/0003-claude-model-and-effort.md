# ADR 0003: Claude Opus 5.5 for every AI task, tuned by effort

- Status: Accepted
- Date: 2026-10-15

## Context
AI tasks range from high-volume classification to open-ended chat. Cost and latency matter, but so does quality.

## Decision
Every task uses `claude-opus-5-5`, tuned per task with `output_config.effort` (`low` for categorize, quick add,
receipts and chat; `medium` for insights and budgets). Model, effort and token limits are server-side config.
Server-side refusal fallback (`fallbacks: "default"`) is enabled on every call.

## Consequences
- Estimated ≈$2.75 per active user per month; chat dominates.
- Switching a task to a cheaper model is a product decision that must pass the offline eval suite first.
- Thinking cannot be disabled on Opus 5.5; prompts never ask the model to reveal its reasoning.
