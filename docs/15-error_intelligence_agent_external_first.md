# Error Intelligence Agent — External-First Architecture

## 1. Idea Summary

We want to build an **error intelligence agent** that helps developers and product teams understand production errors with full context.

Today, when an error happens, a developer usually has to:

1. Open logs in Grafana/Loki or another logging tool.
2. Open Sentry or another error tracking tool.
3. Check user/session data manually.
4. Copy the error into an AI coding tool.
5. Ask the AI to explain what happened.
6. Manually create a ticket or pull request.

The goal is to automate this flow.

The system should collect:

- Error details
- Logs
- Stack traces
- Request metadata
- User/session context
- User journey events
- Related frontend/backend events
- Repetition count
- Similar error patterns

Then an agent should explain:

- What happened
- Why it likely happened
- What data was missing or unexpected
- What user action caused it
- Which code area is likely involved
- Whether it is a new issue or repeated issue
- What developer should check next

Later, the system can also create tickets, assign developers, or generate PRs for human review.

---

## 2. External-First Strategy

For the first version, we should **not build the full observability engine ourselves**.

Instead, we should integrate with existing external services.

External tools already handle:

- Log collection
- Error grouping
- Alerting
- Storage
- Search
- Dashboards
- Rate limits
- Deduplication
- Notification rules
- Webhooks
- Retention

So the first version should use external systems as the source of truth.

Recommended external-first stack:

```text
Application
  ↓
Logger / Sentry SDK / Frontend Tracking
  ↓
Grafana / Loki / Sentry / PostHog-like user journey tool
  ↓
Webhook / API Pull
  ↓
Our Error Intelligence Agent
  ↓
Explanation / Ticket / PR Suggestion
```

---

## 3. Main External Services

### 3.1 Grafana

Grafana should be used for dashboards, alerting, and observability views.

Grafana helps us see:

- Error spikes
- Service health
- Metrics
- Logs through Loki
- Alert rules
- Dashboards

Example:

```text
If the same error happens 10 times in 5 minutes,
Grafana sends a webhook to our agent.
```

Grafana is useful because it prevents us from sending every small log event to the agent.

Instead, Grafana can trigger the agent only when something meaningful happens.

---

### 3.2 Loki

Loki can store and query application logs.

The application sends logs to Loki, and Grafana can visualize/query those logs.

Loki is useful for:

- Searching logs by request ID
- Searching logs by user ID
- Searching logs by service name
- Searching logs by error fingerprint
- Finding logs around the error timestamp

Example query idea:

```text
Find all logs for request_id = abc123
between 10 seconds before and 10 seconds after the error.
```

---

### 3.3 Sentry

Sentry should be used for error tracking.

Sentry helps with:

- Stack traces
- Error grouping
- Release tracking
- User context
- Breadcrumbs
- Environment info
- Browser/device info
- Error frequency

Sentry is especially useful because it already groups similar errors.

Example:

```text
Same error happened 254 times,
affected 37 users,
started after release v1.4.2.
```

This kind of data is very useful for the agent.

---

### 3.4 User Journey / Product Analytics Tool

We also need frontend/user journey information.

This can come from tools like:

- PostHog
- FullStory
- LogRocket
- Highlight.io
- OpenReplay
- Custom frontend event tracking

This layer helps answer:

- What did the user click?
- Which page was the user on?
- What form values were entered?
- What route changed before the error?
- Did the user refresh, retry, or abandon?
- Was there a frontend error before the backend error?

Example:

```text
User opened billing page
→ clicked upgrade plan
→ selected yearly plan
→ clicked checkout
→ backend raised error because billing_account_id was nil
```

This is much more useful than only seeing a stack trace.

---

## 4. What Our Product Adds

External tools already collect data.

Our product should focus on **connecting and explaining** that data.

The agent should combine:

```text
Sentry error
+ Grafana/Loki logs
+ user journey events
+ request metadata
+ code context
+ release information
+ repeated pattern count
```

Then produce a simple explanation.

Example output:

```text
This error happened when the user tried to upgrade from monthly to yearly billing.

The backend expected billing_account_id, but it was nil.

The user journey shows that the user came from the old account settings page, not the new billing setup page.

Likely cause:
Some old accounts do not have billing_account_id populated.

Suggested fix:
Add a fallback lookup or migration for old accounts before creating the checkout session.
```

---

## 5. First Version Flow

### Step 1: Application Sends Data to External Services

The app already logs errors and sends telemetry to tools like Sentry, Grafana, and Loki.

```text
Phoenix / Backend App
  ↓
Logger / Telemetry / Sentry SDK
  ↓
Grafana Loki + Sentry
```

Frontend sends user events to a user journey system.

```text
Frontend App
  ↓
User journey events
  ↓
PostHog / OpenReplay / LogRocket / Custom system
```

---

### Step 2: External Service Triggers Our Agent

When an important error happens, external tools send a webhook.

Example triggers:

```text
New error created in Sentry
Same error happened 10 times
Error affected more than 5 users
Error started after new release
Payment-related error happened
High-priority route failed
```

---

### Step 3: Agent Pulls More Context

The webhook should not contain everything.

It should contain enough identifiers for the agent to fetch more data.

Useful IDs:

```text
error_id
fingerprint
request_id
trace_id
user_id
session_id
release_id
timestamp
service_name
environment
```

The agent then fetches:

```text
Sentry stack trace
Loki logs around timestamp
Grafana alert metadata
User journey timeline
Recent release/deployment info
Related code context if available
```

---

### Step 4: Agent Generates Explanation

The agent should produce different explanation levels.

#### Developer-level explanation

```text
Technical root cause, stack trace summary, likely file/module/function, related logs, suspected data issue.
```

#### Product-level explanation

```text
What user was trying to do, where experience failed, how many users affected, business impact.
```

#### Support-level explanation

```text
Simple customer-facing summary and possible workaround.
```

---

### Step 5: Create Ticket or PR Suggestion

The agent can create a ticket in Linear/Jira/GitHub Issues.

Ticket should include:

```text
Title
Severity
Affected users
Error summary
User journey
Logs summary
Suspected cause
Suggested fix
Links to Sentry/Grafana/user replay
```

Later, it can also open a PR suggestion using a coding agent.

But for safety, PRs should always require human review.

---

## 6. Data Snapshot at Error Time

One important missing piece in many tools is the **state snapshot**.

Logs and traces show what happened, but they may not show enough application state.

We may need to capture important state when an error happens.

Example snapshot:

```json
{
  "user_id": "123",
  "account_id": "456",
  "request_id": "abc",
  "route": "/billing/checkout",
  "params": {
    "plan": "yearly"
  },
  "safe_context": {
    "billing_account_id": null,
    "account_status": "active",
    "plan": "monthly"
  }
}
```

Important: snapshots must be safe.

Do not store sensitive data like:

- Passwords
- Tokens
- Full payment data
- Private user messages
- API keys
- Secrets
- Unmasked personal data

Use allowlists, not blocklists.

Good approach:

```text
Only capture fields that are explicitly allowed.
```

---

## 7. Deduplication and Pressure Handling

The system should not send every error to the agent.

If the same error happens 100 times, the agent should not explain it 100 times.

We need grouping logic.

Possible grouping key:

```text
error_fingerprint
+ service_name
+ environment
+ release_id
+ route
```

Example:

```text
First occurrence:
  Store full context and ask agent to explain.

Repeated occurrence:
  Increment count only.

New data pattern:
  Store as new example under same error group.
```

This can be handled first by external services:

- Sentry issue grouping
- Grafana alert rules
- Loki queries
- PostHog session grouping

Later, if needed, our internal system can add its own grouping logic.

---

## 8. Internal Handling Option for Future

In the future, we can build our own internal event pipeline.

This would give more control but also more responsibility.

Possible internal architecture:

```text
Application Logger / Telemetry
  ↓
Local Event Buffer
  ↓
GenStage / Broadway Pipeline
  ↓
Deduplication Processor
  ↓
Snapshot Processor
  ↓
Agent Queue
  ↓
Storage + Explanation
```

Possible Elixir components:

```text
Logger metadata
Telemetry events
Broadway
GenStage
Oban
Postgres
ETS
Registry
DynamicSupervisor
```

Internal pipeline stages could be:

```text
1. Receive local error event
2. Normalize event
3. Attach metadata
4. Deduplicate by fingerprint
5. Store first snapshot
6. Count repeated errors
7. Fetch related user journey
8. Send important cases to agent
9. Store explanation
10. Create ticket
```

This internal approach is useful if:

- External tools are too expensive
- We need custom data control
- We want self-hosted deployments
- We need deeper Elixir-native integration
- We want to provide an open-source SDK/library

But it is harder because we must handle:

- Backpressure
- Storage
- Retention
- Deduplication
- Privacy
- Rate limits
- Failure recovery
- Replay
- Scaling

So for now, external-first is better.

---

## 9. Open Source SDK / Library Idea

We can provide a small SDK/library that users install in their app.

For Elixir/Phoenix, the library could do:

```text
- Attach request_id, user_id, account_id to Logger metadata
- Capture safe snapshots on error
- Send breadcrumbs/user actions
- Connect Sentry issue with Loki logs
- Send webhook/event to our SaaS
- Provide Plug integration
- Provide Oban integration
- Provide LiveView integration
```

Example developer usage:

```elixir
# router/controller pipeline
plug ErrorIntel.Plug.Context

# in app code
ErrorIntel.snapshot(:billing_checkout, %{
  account_id: account.id,
  plan: plan,
  billing_account_id: account.billing_account_id
})
```

Then, when an error happens, the library can attach safe context.

---

## 10. MVP Scope

First MVP should be simple.

### Must have

```text
Sentry webhook ingestion
Grafana alert webhook ingestion
Loki log lookup by request_id/trace_id
User journey link ingestion
Agent-generated explanation
Error grouping
Ticket creation
```

### Nice to have

```text
Code context lookup
PR suggestion
Session replay video generation
Frontend SDK
Elixir SDK
Slack summaries
Business impact summary
```

### Avoid in first version

```text
Building our own full log storage
Replacing Sentry
Replacing Grafana
Replacing Loki
Building full session replay from scratch
Auto-merging PRs
```

---

## 11. Product Positioning

This is not just another logging tool.

It is an **error understanding layer**.

Existing tools show:

```text
What failed?
Where did it fail?
How many times did it fail?
```

Our product explains:

```text
Why did it fail?
What was the user trying to do?
What data caused it?
What changed recently?
What should the developer check next?
What is the business/user impact?
```

---

## 12. Future Vision

Long term, the system can become an agentic debugging workflow.

Possible future flow:

```text
Error happens
  ↓
System captures logs + user journey + snapshot
  ↓
Agent explains issue
  ↓
Agent creates ticket
  ↓
Agent checks codebase
  ↓
Agent suggests fix
  ↓
Agent opens PR
  ↓
Developer reviews and merges
```

The human stays in control, but the agent removes most of the investigation work.

---

## 13. Recommended Direction

Start with external services first.

Use:

```text
Sentry for error tracking
Grafana/Loki for logs and alerts
PostHog/OpenReplay/LogRocket-like tool for user journey
Our agent for explanation and ticket creation
```

Do not build the full internal pipeline immediately.

Build internal handling later only if:

```text
external tools are limiting us
we need deeper control
customers want self-hosting
we want an open-source Elixir library
we need richer snapshots than external tools allow
```

This keeps the first version practical while still keeping the long-term product vision open.
