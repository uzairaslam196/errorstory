defmodule ErrorStory.ConfigTest do
  use ExUnit.Case, async: false

  alias ErrorStory.Config

  test "resolves environment-backed config values" do
    System.put_env("ERROR_STORY_TEST_VALUE", "configured")

    assert "configured" = Config.resolve_value({:system, "ERROR_STORY_TEST_VALUE"})
  after
    System.delete_env("ERROR_STORY_TEST_VALUE")
  end

  test "uses default for missing environment-backed config values" do
    assert "fallback" =
             Config.resolve_value({:system, "ERROR_STORY_MISSING_TEST_VALUE", "fallback"})
  end
end
