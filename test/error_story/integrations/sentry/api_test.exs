defmodule ErrorStory.Integrations.Sentry.ApiTest do
  use ExUnit.Case, async: true

  alias ErrorStory.Integrations.Sentry.Api

  describe "fetch_issue/2" do
    test "fetches issue details through ErrorStory.Request" do
      Req.Test.expect(ErrorStory.Request, fn conn ->
        assert conn.request_path == "/api/0/issues/issue_123/"
        Req.Test.json(conn, %{"id" => "issue_123"})
      end)

      assert {:ok, %{"id" => "issue_123"}} =
               Api.fetch_issue("issue_123", auth_token: "test_token")
    end
  end

  describe "fetch_project_event/4" do
    test "fetches project event details through ErrorStory.Request" do
      Req.Test.expect(ErrorStory.Request, fn conn ->
        assert conn.request_path == "/api/0/projects/acme/billing/events/event_456/"
        Req.Test.json(conn, %{"event_id" => "event_456"})
      end)

      assert {:ok, %{"event_id" => "event_456"}} =
               Api.fetch_project_event("acme", "billing", "event_456", auth_token: "test_token")
    end
  end

  describe "verify_event_signature/3" do
    test "accepts valid HMAC-SHA256 signatures" do
      raw_body = ~s({"action":"created"})
      secret = "webhook_secret"

      signature =
        :hmac
        |> :crypto.mac(:sha256, secret, raw_body)
        |> Base.encode16(case: :lower)

      assert :ok = Api.verify_event_signature(raw_body, signature, secret)
    end

    test "rejects invalid signatures" do
      assert {:error, :invalid_signature} =
               Api.verify_event_signature(~s({"action":"created"}), "bad", "webhook_secret")
    end
  end
end
