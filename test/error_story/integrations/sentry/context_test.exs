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

  test "hydrates sparse sentry webhook payloads with fetched issue and event details" do
    Req.Test.expect(ErrorStory.Request, 2, fn conn ->
      case conn.request_path do
        "/api/0/issues/issue_123/" ->
          Req.Test.json(conn, %{
            "id" => "issue_123",
            "title" => "RuntimeError: checkout failed",
            "culprit" => "Billing.Checkout.create_session/2",
            "permalink" => "https://sentry.example/issues/issue_123",
            "firstRelease" => %{"version" => "v1.4.2"},
            "metadata" => %{"fingerprint" => "billing-checkout-runtime-error"}
          })

        "/api/0/projects/acme/billing/events/event_456/" ->
          Req.Test.json(conn, %{
            "event_id" => "event_456",
            "message" => "billing_account_id was nil",
            "environment" => "prod",
            "transaction" => "POST /billing/checkout",
            "web_url" => "https://sentry.example/events/event_456",
            "request" => %{"url" => "/billing/checkout", "method" => "POST"},
            "user" => %{"id" => "user_789"},
            "contexts" => %{
              "trace" => %{
                "trace_id" => "trace_abc",
                "data" => %{"request_id" => "req_xyz"}
              }
            },
            "tags" => [["handled", "no"]],
            "exception" => %{
              "values" => [
                %{
                  "stacktrace" => %{
                    "frames" => [
                      %{
                        "filename" => "lib/billing/checkout.ex",
                        "function" => "create_session"
                      }
                    ]
                  }
                }
              ]
            }
          })
      end
    end)

    payload = %{
      "action" => "created",
      "data" => %{
        "issue" => %{"id" => "issue_123"},
        "event" => %{"event_id" => "event_456"}
      }
    }

    assert {:ok,
            %Incident{
              id: "issue_123",
              title: "RuntimeError: checkout failed",
              environment: "prod",
              release: "v1.4.2",
              fingerprint: "billing-checkout-runtime-error",
              route: "/billing/checkout",
              user_id: "user_789",
              request_id: "req_xyz",
              trace_id: "trace_abc",
              stacktrace: [%{"filename" => "lib/billing/checkout.ex"}],
              metadata: %{transaction: "POST /billing/checkout", tags: %{"handled" => "no"}},
              evidence: [%ErrorStory.Evidence{payload: evidence_payload}],
              links: [
                %{source: :sentry, url: "https://sentry.example/issues/issue_123"},
                %{source: :sentry, url: "https://sentry.example/events/event_456"}
              ]
            }} =
             Context.normalize_webhook(payload,
               fetch_details: true,
               auth_token: "test_token",
               organization_slug: "acme",
               project_slug: "billing"
             )

    assert %{
             issue_id: "issue_123",
             event_id: "event_456",
             culprit: "Billing.Checkout.create_session/2",
             transaction: "POST /billing/checkout",
             tags: %{"handled" => "no"},
             action: "created"
           } = evidence_payload

    refute Map.has_key?(evidence_payload, :issue)
    refute Map.has_key?(evidence_payload, :event)
  end

  test "skips event detail fetch when project coordinates are not provided" do
    Req.Test.expect(ErrorStory.Request, fn conn ->
      assert conn.request_path == "/api/0/issues/issue_123/"

      Req.Test.json(conn, %{
        "id" => "issue_123",
        "title" => "Fetched issue title"
      })
    end)

    payload = %{
      "action" => "created",
      "data" => %{
        "issue" => %{"id" => "issue_123"},
        "event" => %{"event_id" => "event_456"}
      }
    }

    assert {:ok, %Incident{title: "Fetched issue title", metadata: %{event_id: "event_456"}}} =
             Context.normalize_webhook(payload, fetch_details: true, auth_token: "test_token")
  end

  test "returns a structured error when issue detail fetch fails" do
    Req.Test.expect(ErrorStory.Request, fn conn ->
      assert conn.request_path == "/api/0/issues/issue_123/"

      conn
      |> Plug.Conn.put_status(401)
      |> Req.Test.json(%{"error" => "unavailable"})
    end)

    payload = %{"data" => %{"issue" => %{"id" => "issue_123"}, "event" => %{}}}

    assert {:error,
            {:sentry_detail_fetch_failed, :issue, {:http_error, 401, %{"error" => "unavailable"}}}} =
             Context.normalize_webhook(payload, fetch_details: true, auth_token: "test_token")
  end

  test "returns a structured error when event detail fetch fails" do
    Req.Test.expect(ErrorStory.Request, fn conn ->
      assert conn.request_path == "/api/0/projects/acme/billing/events/event_456/"

      conn
      |> Plug.Conn.put_status(401)
      |> Req.Test.json(%{"error" => "unavailable"})
    end)

    payload = %{
      "data" => %{
        "issue" => %{},
        "event" => %{"event_id" => "event_456"}
      }
    }

    assert {:error,
            {:sentry_detail_fetch_failed, :event, {:http_error, 401, %{"error" => "unavailable"}}}} =
             Context.normalize_webhook(payload,
               fetch_details: true,
               auth_token: "test_token",
               organization_slug: "acme",
               project_slug: "billing"
             )
  end
end
