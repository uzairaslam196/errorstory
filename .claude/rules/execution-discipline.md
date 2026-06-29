# Execution Discipline

## Workflow

1. Read `CLAUDE.md` and `AGENTS.md` before non-trivial work.
2. Plan first for architectural or multi-file changes.
3. Keep diffs minimal and tied to the requested outcome.
4. Verify before done.
5. Run a review pass against the Iron Laws.

## Outside-In Public APIs

Every new public function must have one of:

- a concrete user-facing library purpose
- a behaviour callback contract
- a caller in the current phase

Do not add public functions because they might be useful later.

## Pipeline-First Provider Thinking

For provider-backed features, design the generic pipeline and variation points:

```text
provider payload/API
  -> provider Context normalization
  -> %ErrorStory.Incident{} / [%ErrorStory.Evidence{}]
  -> explanation / scene plan
  -> deterministic report/video rendering
```

Adding a provider should mostly add a provider `Api` and `Context`, not change the agent or video modules.

## Designing For Vs. Building For Scale

- Design names and boundaries so five more providers can fit later.
- Do not build unused infrastructure without a caller.
- At the second concrete implementation, extract repeated shape deliberately.

## Quality Gates

Run for non-trivial changes:

```bash
mix test
mix format --check-formatted
mix compile --warnings-as-errors
```

If a gate fails, fix and rerun. After three failed repair loops, escalate with the blocker.
