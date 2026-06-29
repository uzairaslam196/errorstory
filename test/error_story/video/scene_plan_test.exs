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

  test "does not create browser scenes from visual types without references" do
    {:ok, screenshot_evidence} =
      Evidence.new(type: :screenshot, source: :playwright, visual: %{}, summary: "empty visual")

    {:ok, incident} = Incident.new(title: "Checkout failed", evidence: [screenshot_evidence])

    assert {:ok, %ScenePlan{scenes: scenes, warnings: [warning]}} =
             ScenePlan.from_incident(incident)

    refute Enum.any?(scenes, &(&1.type == :browser_view))
    assert warning =~ "No visual evidence"
  end

  test "creates browser scenes from screenshot, replay, and DOM visual evidence" do
    {:ok, screenshot_evidence} =
      ErrorStory.visual_evidence(:screenshot, %{
        source: :post_hog,
        summary: "Billing page before checkout",
        url: "https://cdn.example/frame.png",
        route: "/billing"
      })

    {:ok, replay_evidence} =
      ErrorStory.visual_evidence(:replay, %{
        source: :logrocket,
        replay_url: "https://app.logrocket.com/replay/123"
      })

    {:ok, dom_snapshot_evidence} =
      ErrorStory.visual_evidence(:dom_snapshot, %{
        dom_snapshot_id: "dom_123",
        route: "/billing"
      })

    {:ok, incident} =
      Incident.new(
        title: "Checkout failed",
        evidence: [screenshot_evidence, replay_evidence, dom_snapshot_evidence]
      )

    assert {:ok, %ScenePlan{scenes: scenes, warnings: []}} = ScenePlan.from_incident(incident)

    assert [
             %{evidence: %{evidence_type: :screenshot}},
             %{evidence: %{evidence_type: :replay}},
             %{evidence: %{evidence_type: :dom_snapshot}}
           ] = Enum.filter(scenes, &(&1.type == :browser_view))
  end

  test "includes visual metadata in browser scenes" do
    occurred_at = ~U[2026-01-02 03:04:05Z]

    {:ok, screenshot_evidence} =
      ErrorStory.visual_evidence(:screenshot, %{
        source: :post_hog,
        summary: "Billing page before checkout",
        url: "https://cdn.example/frame.png",
        route: "/billing",
        viewport: %{width: 1440, height: 900},
        occurred_at: occurred_at,
        highlight: %{selector: "#pay", text: "Pay <now>"}
      })

    {:ok, incident} = Incident.new(title: "Checkout failed", evidence: [screenshot_evidence])

    assert {:ok, %ScenePlan{scenes: scenes, warnings: []}} = ScenePlan.from_incident(incident)

    assert %{
             type: :browser_view,
             caption: "Billing page before checkout",
             evidence: %{
               source: :post_hog,
               evidence_type: :screenshot,
               route: "/billing",
               viewport: %{width: 1440, height: 900},
               url: "https://cdn.example/frame.png",
               timestamp: ^occurred_at,
               highlight: %{selector: "#pay", text: "Pay <now>"}
             }
           } = Enum.find(scenes, &(&1.type == :browser_view))
  end

  test "attaches a related journey event when routes match" do
    {:ok, journey_evidence} =
      Evidence.new(
        type: :journey_event,
        source: :post_hog,
        summary: "clicked pay",
        payload: %{route: "/billing"}
      )

    {:ok, screenshot_evidence} =
      ErrorStory.visual_evidence(:screenshot, %{
        url: "https://cdn.example/frame.png",
        route: "/billing"
      })

    {:ok, incident} =
      Incident.new(title: "Checkout failed", evidence: [journey_evidence, screenshot_evidence])

    assert {:ok, %ScenePlan{scenes: scenes}} = ScenePlan.from_incident(incident)

    assert %{evidence: %{related_journey_event: %{summary: "clicked pay"}}} =
             Enum.find(scenes, &(&1.type == :browser_view))
  end
end
