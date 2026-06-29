---
name: planning
description: Plan architectural or multi-file ErrorStory work before implementation.
---

# Planning Skill

Use for vague, architectural, provider, or multi-file work.

Plan from the outside in:

1. Identify the library user and public API.
2. Identify normalized structs and provider variation points.
3. Keep core free of Phoenix/Ecto/Oban assumptions.
4. Define tests and quality gates.
5. Check `AGENTS.md` Iron Laws.

For provider work, show the pipeline:

```text
provider payload/API -> provider Context -> Incident/Evidence -> agent/video
```
