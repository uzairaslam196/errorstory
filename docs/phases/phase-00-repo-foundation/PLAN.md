# Phase 00 - Repo Foundation

## Goal

Create the ErrorStory open source library foundation: adapted repo instructions, Iron Laws, quality rules, a minimal Mix library scaffold, normalized incident contracts, provider boundaries, and initial tests.

## Out Of Scope

- Full production integrations with Sentry, Loki, PostHog, or OpenAI.
- Phoenix dashboard, Ecto persistence, Oban workers, or deploy setup.
- Real video encoding pipeline.

## Context

- Source idea: `docs/15-error_intelligence_agent_external_first.md`
- Adapted guidance source: sibling `../note_panda/CLAUDE.md`, `../note_panda/AGENTS.md`, and rules/skills files.

## Tasks

1. **Repo instructions and rules**
   - Files: `CLAUDE.md`, `AGENTS.md`, `.claude/rules/*`, `.agents/skills/core/*`
   - Acceptance: no stale NotePanda module names outside historical references.

2. **Mix library skeleton**
   - Files: `mix.exs`, `.formatter.exs`, `config/test.exs`, `lib/error_story*`
   - Acceptance: project compiles as an Elixir library.

3. **Core contracts**
   - Files: `lib/error_story/incident.ex`, `lib/error_story/evidence.ex`, `lib/error_story/video/scene_plan.ex`
   - Acceptance: public APIs build normalized incidents and scene plans without provider payload leakage.

4. **Provider boundary examples**
   - Files: `lib/error_story/integrations/*`
   - Acceptance: providers follow `Api` / `Context` separation and mocked HTTP boundary.

5. **Tests**
   - Files: `test/**/*_test.exs`
   - Acceptance: `mix test` passes and covers key public behavior.

## Agent Dispatch

- Parallel review: instruction adaptation and library architecture review.
- Main thread: implementation and final integration.

## Risks And Mitigations

- **App-specific rules leak into library** -> keep Phoenix/Ecto/Oban guidance optional only.
- **Video plans hallucinate UI** -> browser scenes require visual evidence references.
- **Provider abstractions become too broad** -> keep first contracts small and behaviour-driven.

## Verification

- [x] `mix test`
- [x] `mix format --check-formatted`
- [x] `mix compile --warnings-as-errors`
- [x] Iron Laws review
- [x] No debug artifacts

## Status

`done`
