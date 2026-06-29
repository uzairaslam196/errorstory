defmodule ErrorStory.Integrations.Sentry.ApiTest do
  use ExUnit.Case, async: true

  alias ErrorStory.Integrations.Sentry.Api

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
