defmodule ErrorStory.Integrations.OpenAI.ContextTest do
  use ExUnit.Case, async: true

  alias ErrorStory.Incident
  alias ErrorStory.Integrations.OpenAI.Context

  test "asks OpenAI for a JSON explanation through ErrorStory.Request" do
    Req.Test.expect(ErrorStory.Request, fn conn ->
      assert conn.request_path == "/v1/chat/completions"

      Req.Test.json(conn, %{
        "choices" => [
          %{
            "message" => %{
              "content" =>
                Jason.encode!(%{
                  developer_summary: "Checkout failed because billing_account_id was nil",
                  product_summary: "Upgrade flow failed",
                  support_summary: "Customer could not upgrade",
                  likely_cause: "Missing billing account",
                  next_checks: ["Check billing account migration"]
                })
            }
          }
        ]
      })
    end)

    {:ok, incident} = Incident.new(title: "Checkout failed")

    assert {:ok,
            %{
              "developer_summary" => "Checkout failed because billing_account_id was nil",
              "next_checks" => ["Check billing account migration"]
            }} =
             Context.explain_incident(incident,
               api_key: "test_key",
               model: "gpt-4o-mini"
             )
  end
end
