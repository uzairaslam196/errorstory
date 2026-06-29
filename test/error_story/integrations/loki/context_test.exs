defmodule ErrorStory.Integrations.Loki.ContextTest do
  use ExUnit.Case, async: true

  alias ErrorStory.Incident
  alias ErrorStory.Integrations.Loki.Context

  test "fetches logs through ErrorStory.Request and normalizes log evidence" do
    Req.Test.expect(ErrorStory.Request, fn conn ->
      assert conn.request_path == "/loki/api/v1/query_range"
      assert URI.decode_query(conn.query_string)["query"] == ~s({request_id="req_123"})

      Req.Test.json(conn, %{
        "data" => %{
          "result" => [
            %{
              "stream" => %{"service" => "billing"},
              "values" => [["1", "billing_account_id=nil"]]
            }
          ]
        }
      })
    end)

    {:ok, incident} = Incident.new(title: "Checkout failed", request_id: "req_123")

    assert {:ok, [log_evidence]} =
             Context.fetch_logs(incident, base_url: "https://loki.example")

    assert log_evidence.type == :log
    assert log_evidence.source == :loki
    assert log_evidence.summary == "billing_account_id=nil"
  end

  test "escapes incident ids before building LogQL selectors" do
    Req.Test.expect(ErrorStory.Request, fn conn ->
      query = URI.decode_query(conn.query_string)["query"]

      assert query == ~s({request_id="req_123\\"} |= \\"leak"})
      refute query == ~s({request_id="req_123"} |= "leak"})

      Req.Test.json(conn, %{"data" => %{"result" => []}})
    end)

    {:ok, incident} = Incident.new(title: "Checkout failed", request_id: ~s(req_123"} |= "leak))

    assert {:ok, []} = Context.fetch_logs(incident, base_url: "https://loki.example")
  end

  test "requires a request id or trace id" do
    {:ok, incident} = Incident.new(title: "Checkout failed")

    assert {:error, :missing_request_or_trace_id} = Context.fetch_logs(incident)
  end
end
