# Code Style

## Module Organization

Organize Elixir modules from top to bottom:

1. `@moduledoc`
2. Module attributes
3. `require`
4. `use`
5. `import`
6. `alias`
7. Public functions with `@doc`
8. Private functions

## Documentation

- Every module has `@moduledoc`.
- Every public function has `@doc`.
- Use `@spec` for public functions with meaningful contracts.

## Naming

- Prefer domain names: `incident`, `evidence`, `scene_plan`, `safe_snapshot_attrs`.
- Do not use generic names like `data`, `item`, or `context` when a concrete name is available.
- Distinguish provider payloads from normalized structs.

## Logging

- `Logger.info` for key lifecycle events.
- `Logger.warning` for unexpected but non-fatal conditions.
- `Logger.error` for failures.
- `Logger.debug` for low-level diagnostics.
- Never log secrets, tokens, auth headers, cookies, full bodies, or arbitrary snapshots.

## General

- Use `ErrorStory.Request` for outbound HTTP.
- Return `{:ok, result}` / `{:error, reason}` from service functions.
- Pattern match at function heads when natural.
- Do not extract one-call wrapper helpers.
- Keep core library code free of Phoenix/Ecto/Oban assumptions.
