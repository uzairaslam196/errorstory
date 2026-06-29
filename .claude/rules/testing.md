# Testing Rules

## External API Mocking

All external HTTP calls must be mocked in tests. Never hit real Sentry, Loki, PostHog, OpenAI, or customer apps in normal test runs.

Use `Req.Test` through `ErrorStory.Request` when testing provider HTTP code.

## Test File Location

This is an open source Elixir library. Use standard ExUnit layout:

```text
test/**/*_test.exs
test/support/*
```

Large external API responses should live under a matching fixture directory in `test/fixtures/`.

## Assertions

Prefer pattern matching on whole responses:

```elixir
assert {:ok, %ErrorStory.Incident{id: "evt_123", source: :sentry}} =
         ErrorStory.normalize(:sentry, payload)
```

Use individual asserts for guards or partial text checks.

## Coverage Expectations

- Success path and error path for public functions.
- Provider normalization from representative fixtures.
- Webhook signature success and failure.
- Scene plans must not invent browser scenes when visual evidence is absent.

## Avoid

- `Process.sleep/1`
- real network calls
- redundant tests that verify the same path through a different wrapper
- implementation-detail tests for private helpers
