defmodule ErrorStory.Integrations.Sentry.ContextTest do
  use ExUnit.Case, async: true

  alias ErrorStory.Incident
  alias ErrorStory.Integrations.Sentry.Context

  test "normalizes the canonical Sentry fixture into MVP incident fields" do
    payload =
      "test/fixtures/sentry/issue_webhook.json"
      |> File.read!()
      |> Jason.decode!()

    assert {:ok,
            %Incident{
              id: "issue_123",
              source: :sentry,
              title: "RuntimeError: checkout failed",
              environment: "prod",
              release: "v1.4.2",
              fingerprint: "billing-checkout-runtime-error",
              request_id: "req_xyz",
              trace_id: "trace_abc",
              user_id: "user_789",
              route: "/billing/checkout",
              stacktrace: [first_frame | _],
              metadata: %{
                event_id: "event_456",
                culprit: "Billing.Checkout.create_session/2",
                transaction: "POST /billing/checkout",
                method: "POST",
                tags: %{"handled" => "no", "level" => "error"}
              },
              links: [
                %{source: :sentry, url: "https://sentry.example/issues/issue_123"},
                %{source: :sentry, url: "https://sentry.example/events/event_456"}
              ]
            }} = Context.normalize_webhook(payload)

    assert %{"filename" => "lib/billing/checkout.ex", "function" => "create_session"} =
             first_frame
  end

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
              evidence: [
                %ErrorStory.Evidence{
                  source: :sentry,
                  type: :error,
                  payload: evidence_payload
                }
              ],
              links: [%{source: :sentry, url: "https://sentry.example/issues/123"}]
            }} = Context.normalize_webhook(payload)

    assert %{
             issue_id: "123",
             event_id: nil,
             transaction: nil,
             tags: %{},
             action: "created"
           } = evidence_payload

    refute Map.has_key?(evidence_payload, :issue)
    refute Map.has_key?(evidence_payload, :event)
  end
end
