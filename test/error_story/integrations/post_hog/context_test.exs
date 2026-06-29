defmodule ErrorStory.Integrations.PostHog.ContextTest do
  use ExUnit.Case, async: true

  alias ErrorStory.Incident
  alias ErrorStory.Integrations.PostHog.Context

  test "fetches journey events through ErrorStory.Request and normalizes evidence" do
    Req.Test.expect(ErrorStory.Request, fn conn ->
      assert conn.request_path == "/api/projects/project_123/events/"
      assert conn.query_string =~ "distinct_id=user_123"

      Req.Test.json(conn, %{
        "results" => [
          %{
            "event" => "$pageview",
            "properties" => %{"$current_url" => "/billing"}
          }
        ]
      })
    end)

    {:ok, incident} = Incident.new(title: "Checkout failed", user_id: "user_123")

    assert {:ok, [journey_evidence]} =
             Context.fetch_journey(incident,
               base_url: "https://posthog.example",
               project_id: "project_123",
               api_key: "test_key"
             )

    assert journey_evidence.type == :journey_event
    assert journey_evidence.source == :post_hog
    assert journey_evidence.summary == "$pageview"
  end

  test "requires a user or session id" do
    {:ok, incident} = Incident.new(title: "Checkout failed")

    assert {:error, :missing_user_or_session_id} = Context.fetch_journey(incident)
  end
end
