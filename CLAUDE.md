# ErrorStory

Open source Elixir library for turning production errors into grounded incident explanations and lightweight, evidence-based video/report plans.

ErrorStory is a library first. Any Elixir or Phoenix project should be able to add it as a dependency, configure provider API keys, and use it without adopting this repo's storage, web framework, job system, or deployment model.

## Commands

```bash
mix deps.get
mix test
mix format
mix compile --warnings-as-errors
```

Run `mix test` before finalizing changes. Run `mix format --check-formatted` and `mix compile --warnings-as-errors` for non-trivial changes.

## Critical Rules

- **All outbound HTTP goes through `ErrorStory.Request`**. Provider modules do not call `Req.get/post` directly.
- **All external HTTP is mocked in tests**. Normal test runs must never hit real Sentry, Loki, PostHog, OpenAI, or customer apps.
- **Provider code uses `Api` / `Context` separation**. `Api` owns raw I/O, auth, base URLs, and webhook signature checks. `Context` owns normalization and provider-specific meaning.
- **Agents consume normalized incidents only**. Agent, explanation, and video planning code must not branch on Sentry/PostHog/Loki payload shapes.
- **Snapshots are allowlist-only**. Never capture secrets, tokens, payment data, or arbitrary request params.
- **Iron Laws live in `AGENTS.md`**. Check them before writing code or suggesting refactors.

## Code Style Preference

Optimize first for code that explains the business flow to a human reader.

- Start from the plain-language flow before writing code. If the flow is "normalize webhook, fetch logs, build incident, generate scene plan", function order and names should read that way.
- Prefer direct domain names over generic names. Avoid names like `data`, `item`, `row`, or `context` when the value has a clearer meaning such as `incident_evidence`, `scene_steps`, or `safe_snapshot_attrs`.
- Name different data shapes differently. Provider payloads, normalized incidents, LLM prompts, and rendered scene plans are different contracts.
- Keep provider-specific rules inside provider `Context` modules. Generic handlers call behaviours/routers and should not switch on provider-specific fields.
- Prefer the simplest local helper that explains a real step. Do not add one-call wrappers or premature abstractions.
- Keep private helpers in reading order: high-level flow helpers first, low-level conversion helpers later.
- Use grouped constants when they explain a domain boundary, such as evidence types or supported provider atoms.
- Prefer pipeline-first collection flow when it reads like the business process.
- Do not hide important data changes inside function arguments. Assign the changed value first, then pass it forward.
- Keep operational counts honest. `normalized_count`, `missing_visual_count`, and `failed_fetch_count` are different facts.

## Project Structure

- `lib/error_story.ex` - public library entrypoint
- `lib/error_story/request.ex` - central HTTP wrapper
- `lib/error_story/config.ex` - configuration helpers
- `lib/error_story/incident.ex` - canonical normalized incident shape
- `lib/error_story/evidence.ex` - canonical evidence item shape
- `lib/error_story/integrations/*` - provider behaviours and provider adapters
- `lib/error_story/video/*` - deterministic scene planning/rendering boundaries
- `test/` - ExUnit tests and support helpers

## Provider Design

External tools are evidence sources. They do not own the product story.

Each provider follows this shape:

```text
lib/error_story/integrations/<provider>/api.ex
lib/error_story/integrations/<provider>/context.ex
```

Use `oauth.ex` only if a provider needs an OAuth handshake.

- `Api`: raw HTTP, base URLs, auth headers, endpoint methods, webhook signature verification.
- `Context`: translates provider payloads into `%ErrorStory.Incident{}` and `%ErrorStory.Evidence{}`.
- Behaviour/router modules: define provider capability contracts, such as error tracking, log lookup, journey lookup, and LLM explanation.

## Video Principle

The LLM writes a script or structured scene plan. Deterministic code renders it.

Video/report code must use real evidence: screenshots, replay frames, DOM captures, routes, logs, stack traces, and timestamps. If visual evidence is missing, render timeline/text scenes instead of inventing UI screens.

## Rules And Skills Routing

Always follow:

- `.claude/rules/code-style.md`
- `.claude/rules/testing.md`
- `.claude/rules/execution-discipline.md`
- `AGENTS.md`

Use the adapted skills in `.agents/skills/core/` when applicable:

- `planning` for architectural or multi-file work
- `codebase-research` before non-trivial changes in unfamiliar areas
- `http-external-services` when touching providers or HTTP
- `test-generator` when adding coverage
- `review` before marking non-trivial work complete
