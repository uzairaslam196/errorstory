# Phase 01 - Sentry Runnable MVP

## Goal

Make ErrorStory useful end-to-end for one real production error source: Sentry. A developer should be able to normalize a Sentry webhook fixture, optionally enrich the incident, generate an explanation, build a scene plan, and render a grounded HTML report artifact.

## Out Of Scope

- Phoenix dashboard, Ecto persistence, Oban workers, or deploy setup.
- Real MP4/WebM encoding.
- Real external API calls in default tests.
- Full Sentry product coverage beyond issue/event MVP fields.

## Context

- Phase 00: `docs/phases/phase-00-repo-foundation/PLAN.md`
- Source idea: `docs/15-error_intelligence_agent_external_first.md`
- Provider architecture: `README.md`

## Tasks

1. **Sentry normalization depth**
   - Files: `lib/error_story/integrations/sentry/*`, `priv/fixtures/sentry_issue_webhook.json`
   - Acceptance: fixture normalizes issue id, event id, title, environment, release, route, user id, request id, trace id, culprit, transaction, tags, stack frames, and links.

2. **Report orchestration**
   - Files: `lib/error_story.ex`, `lib/error_story/report.ex`
   - Acceptance: `ErrorStory.report/2` returns incident, explanation, scene plan, and HTML artifact; provider enrichment failures return a structured partial report.

3. **Grounded renderer**
   - Files: `lib/error_story/video/html_report.ex`
   - Acceptance: HTML includes summary, next checks, warnings, logs, journey evidence, stack trace, links, and escaped text.

4. **Runnable demo**
   - Files: `lib/mix/tasks/error_story.demo.ex`, `README.md`
   - Acceptance: `mix error_story.demo` writes an HTML report to `tmp/error_story_demo_report.html`.

5. **Tests**
   - Files: `test/**/*_test.exs`
   - Acceptance: mocked tests cover Sentry API fetch methods, fixture normalization, report success/partial failure, renderer sections, and demo task output.

## Verification

- [x] `mix test`
- [x] `mix format --check-formatted`
- [x] `mix compile --warnings-as-errors`
- [x] `mix error_story.demo`
- [x] No direct `Req.*` outside `ErrorStory.Request`
- [x] No debug artifacts

## Status

`done`
