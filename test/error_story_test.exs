defmodule ErrorStoryTest do
  use ExUnit.Case, async: true

  alias ErrorStory.Evidence
  alias ErrorStory.Incident
  alias ErrorStory.Explanation
  alias ErrorStory.TestSupport.FailingJourneyProvider
  alias ErrorStory.TestSupport.FakeLLMProvider
  alias ErrorStory.TestSupport.FakeLogProvider
  alias ErrorStory.Video.ScenePlan

  describe "capture/2" do
    test "builds a normalized incident from an exception" do
      exception = %RuntimeError{message: "checkout failed"}

      assert {:ok,
              %Incident{
                source: :error_story,
                title: "checkout failed",
                service: "billing",
                request_id: "req_123"
              }} =
               ErrorStory.capture(exception,
                 service: "billing",
                 request_id: "req_123"
               )
    end

    test "captures non-exception terms without raising" do
      assert {:ok, %Incident{title: ":checkout_failed", error: :checkout_failed}} =
               ErrorStory.capture(:checkout_failed)
    end
  end

  describe "snapshot/3" do
    test "keeps only explicitly allowed keys" do
      attrs = %{
        account_id: "acct_123",
        billing_account_id: nil,
        token: "secret"
      }

      assert {:ok,
              %{
                name: :billing_checkout,
                attrs: %{account_id: "acct_123", billing_account_id: nil}
              }} =
               ErrorStory.snapshot(:billing_checkout, attrs,
                 allow: [:account_id, :billing_account_id]
               )
    end
  end

  describe "visual_evidence/3" do
    test "builds screenshot evidence with URL and file path references" do
      occurred_at = ~U[2026-01-02 03:04:05Z]

      assert {:ok,
              %Evidence{
                type: :screenshot,
                source: :playwright,
                occurred_at: ^occurred_at,
                summary: "Checkout failure",
                visual: visual,
                links: [%{source: :screenshot, url: "https://cdn.example/frame.png"}]
              }} =
               ErrorStory.visual_evidence(:screenshot, %{
                 source: :playwright,
                 summary: "Checkout failure",
                 url: "https://cdn.example/frame.png",
                 file_path: "/tmp/frame.png",
                 route: "/billing",
                 occurred_at: occurred_at,
                 token: "secret"
               })

      assert visual == %{
               route: "/billing",
               url: "https://cdn.example/frame.png",
               file_path: "/tmp/frame.png",
               occurred_at: occurred_at
             }
    end

    test "builds replay evidence with a replay URL" do
      assert {:ok,
              %Evidence{
                type: :replay,
                source: :logrocket,
                visual: %{replay_url: "https://app.logrocket.com/replay/123"}
              }} =
               ErrorStory.visual_evidence(:replay, %{
                 source: :logrocket,
                 replay_url: "https://app.logrocket.com/replay/123"
               })
    end

    test "builds DOM snapshot evidence with a snapshot id" do
      assert {:ok,
              %Evidence{
                type: :dom_snapshot,
                visual: %{dom_snapshot_id: "dom_123", route: "/checkout"}
              }} =
               ErrorStory.visual_evidence(:dom_snapshot, %{
                 dom_snapshot_id: "dom_123",
                 route: "/checkout"
               })
    end

    test "rejects visual evidence with no real reference" do
      assert {:error, {:missing_visual_reference, :screenshot}} =
               ErrorStory.visual_evidence(:screenshot, %{summary: "Missing reference"})
    end

    test "rejects unsupported visual evidence types" do
      assert {:error, {:unsupported_visual_evidence_type, :heatmap}} =
               ErrorStory.visual_evidence(:heatmap, %{url: "https://example.com/frame.png"})
    end
  end

  describe "enrich/2" do
    test "adds provider evidence to an incident" do
      {:ok, incident} = Incident.new(title: "Checkout failed")

      assert {:ok, %Incident{evidence: [log_evidence]}} =
               ErrorStory.enrich(incident, logs: {FakeLogProvider, []})

      assert log_evidence.source == :loki
      assert log_evidence.summary == "request failed"
    end

    test "returns failures with the partial incident" do
      {:ok, incident} = Incident.new(title: "Checkout failed")

      assert {:error,
              {:enrichment_failed, [journey: :post_hog_unavailable],
               %Incident{title: "Checkout failed"}}} =
               ErrorStory.enrich(incident, journey: {FailingJourneyProvider, []})
    end
  end

  describe "explain/2" do
    test "creates a deterministic local explanation by default" do
      {:ok, incident} =
        Incident.new(title: "Checkout failed", route: "/billing", request_id: "req_123")

      assert {:ok,
              %Explanation{
                developer_summary: developer_summary,
                product_summary: "A user-facing flow failed on /billing.",
                next_checks: next_checks
              }} = ErrorStory.explain(incident)

      assert developer_summary =~ "Checkout failed"
      assert "Fetch logs for request_id req_123." in next_checks
    end

    test "can delegate explanation to an LLM provider" do
      {:ok, incident} = Incident.new(title: "Checkout failed")

      assert {:ok,
              %Explanation{
                developer_summary: "LLM developer summary",
                next_checks: ["Check the checkout flow"]
              }} = ErrorStory.explain(incident, llm: {FakeLLMProvider, []})
    end
  end

  describe "render_report/2" do
    test "renders a scene plan as deterministic html" do
      scene_plan = %ScenePlan{
        title: "Checkout failed",
        scenes: [
          %{
            type: :summary,
            title: "Incident summary",
            caption: "<Checkout failed>",
            evidence: %{source: :error_story}
          }
        ]
      }

      assert {:ok, html} = ErrorStory.render_report(scene_plan)
      assert html =~ ~s(data-error-story-report="true")
      assert html =~ "&lt;Checkout failed&gt;"
    end
  end

  describe "video_plan/2 and render_video/2" do
    test "uses the public video API names from the library plan" do
      {:ok, incident} = Incident.new(title: "Checkout failed")

      assert {:ok, %ScenePlan{} = scene_plan} = ErrorStory.video_plan(incident)

      assert {:ok, %{format: :html_report, content: html}} =
               ErrorStory.render_video(scene_plan)

      assert html =~ ~s(data-error-story-report="true")
    end
  end

  describe "report/2" do
    test "builds a complete report through the public API" do
      {:ok, incident} = Incident.new(title: "Checkout failed", request_id: "req_123")

      assert {:ok,
              %{
                incident: %Incident{evidence: [_log]},
                explanation: %Explanation{},
                scene_plan: %ScenePlan{},
                artifact: %{format: :html_report, content: html}
              }} = ErrorStory.report(incident, logs: {FakeLogProvider, []})

      assert html =~ "request failed"
    end
  end
end
