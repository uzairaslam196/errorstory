---
name: http-external-services
description: Guidance for ErrorStory provider HTTP and webhook code.
---

# HTTP And External Services

All outbound HTTP goes through `ErrorStory.Request`.

Provider layout:

```text
<provider>/api.ex      # raw HTTP, auth, base URL, webhook signature verification
<provider>/context.ex  # normalization and provider-specific meaning
```

Webhook signature verification happens before any side effect.

Tests mock external HTTP with `Req.Test` or provider fixtures.
