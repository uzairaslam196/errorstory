---
name: review
description: Review ErrorStory changes against Iron Laws and quality gates.
---

# Review Skill

Check first:

- `AGENTS.md` Iron Laws
- provider payloads do not leak into agent/video code
- all HTTP goes through `ErrorStory.Request`
- no secrets or arbitrary snapshots in logs
- tests are meaningful and mocked

Run:

```bash
mix test
mix format --check-formatted
mix compile --warnings-as-errors
```
