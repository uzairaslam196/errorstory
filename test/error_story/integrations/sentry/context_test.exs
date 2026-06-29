defmodule ErrorStory.Integrations.Sentry.ContextTest do
  use ExUnit.Case, async: true

  alias ErrorStory.Incident
  alias ErrorStory.Integrations.Sentry.Context

  test "normalizes a sentry webhook payload into an incident" do
    payload = %{
      "action" => "created",
      "data" => %{
        "issue" => %{
          "id" => "123",
          "title" => "RuntimeError: checkout failed",
          "permalink" => "https://sentry.example/issues/123"
        },
        "event" => %{
          "environment" => "prod",
          "release" => "v1.4.2",
          "request" => %{"url" => "/billing"},
          "user" => %{"id" => "user_123"},
          "contexts" => %{
            "trace" => %{
              "trace_id" => "trace_123",
              "data" => %{"request_id" => "req_123"}
            }
          }
        }
      }
    }

    assert {:ok,
            %Incident{
              id: "123",
              source: :sentry,
              title: "RuntimeError: checkout failed",
              environment: "prod",
              release: "v1.4.2",
              route: "/billing",
              user_id: "user_123",
              request_id: "req_123",
              trace_id: "trace_123",
              evidence: [error_evidence],
              links: [%{source: :sentry, url: "https://sentry.example/issues/123"}]
            }} = Context.normalize_webhook(payload)

    assert error_evidence.source == :sentry
    assert error_evidence.type == :error
  end
end
