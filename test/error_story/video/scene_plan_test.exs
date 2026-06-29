defmodule ErrorStory.Video.ScenePlanTest do
  use ExUnit.Case, async: true

  alias ErrorStory.Evidence
  alias ErrorStory.Incident
  alias ErrorStory.Video.ScenePlan

  test "does not invent browser scenes when visual evidence is missing" do
    {:ok, log_evidence} =
      Evidence.new(type: :log, source: :loki, summary: "billing_account_id=nil")

    {:ok, incident} = Incident.new(title: "Checkout failed", evidence: [log_evidence])

    assert {:ok, %ScenePlan{scenes: scenes, warnings: [warning]}} =
             ScenePlan.from_incident(incident)

    refute Enum.any?(scenes, &(&1.type == :browser_view))
    assert warning =~ "No visual evidence"
  end

  test "uses real visual evidence for browser scenes" do
    {:ok, screenshot_evidence} =
      Evidence.new(
        type: :screenshot,
        source: :post_hog,
        summary: "Billing page before checkout",
        visual: %{url: "https://cdn.example/frame.png", route: "/billing"}
      )

    {:ok, incident} = Incident.new(title: "Checkout failed", evidence: [screenshot_evidence])

    assert {:ok, %ScenePlan{scenes: scenes, warnings: []}} = ScenePlan.from_incident(incident)
    assert Enum.any?(scenes, &(&1.type == :browser_view))
  end
end
