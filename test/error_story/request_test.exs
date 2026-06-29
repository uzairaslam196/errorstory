defmodule ErrorStory.RequestTest do
  use ExUnit.Case, async: true

  alias ErrorStory.Request

  test "normalizes successful responses" do
    Req.Test.expect(ErrorStory.Request, fn conn ->
      Req.Test.json(conn, %{"ok" => true})
    end)

    client = Request.new(base_url: "https://example.test")

    assert {:ok, %{status: 200, body: %{"ok" => true}}} = Request.get(client, "/ok")
  end
end
