defmodule ErrorStory.Video.HtmlReportTest do
  use ExUnit.Case, async: true

  alias ErrorStory.Video.HtmlReport
  alias ErrorStory.Video.ScenePlan
  alias ErrorStory.{Evidence, Explanation, Incident}

  test "escapes scene captions and renders warnings" do
    scene_plan = %ScenePlan{
      title: "Checkout <failed>",
      scenes: [
        %{
          type: :summary,
          title: "Incident summary",
          caption: "<script>alert(1)</script>",
          evidence: %{source: :error_story}
        }
      ],
      warnings: ["No visual evidence was available."]
    }

    assert {:ok, html} = HtmlReport.render(scene_plan)
    assert html =~ "Checkout &lt;failed&gt;"
    assert html =~ "&lt;script&gt;alert(1)&lt;/script&gt;"
    assert html =~ ~s(data-warnings="true")
  end

  test "renders incident, explanation, logs, journey, stack trace, and links" do
    {:ok, log_evidence} =
      Evidence.new(type: :log, source: :loki, summary: "billing_account_id=nil")

    {:ok, journey_evidence} =
      Evidence.new(type: :journey_event, source: :post_hog, summary: "clicked upgrade")

    {:ok, incident} =
      Incident.new(
        title: "Checkout failed",
        source: :sentry,
        route: "/billing",
        request_id: "req_123",
        stacktrace: [
          %{
            "module" => "Billing.Checkout",
            "function" => "create_session",
            "filename" => "checkout.ex",
            "lineno" => 42
          }
        ],
        links: [%{source: :sentry, url: "https://sentry.example/issues/1"}],
        evidence: [log_evidence, journey_evidence]
      )

    explanation = %Explanation{
      developer_summary: "Developer summary",
      product_summary: "Product summary",
      support_summary: "Support summary",
      likely_cause: "Likely cause",
      next_checks: ["Check logs"]
    }

    scene_plan = %ScenePlan{title: "Checkout failed", scenes: []}

    assert {:ok, html} =
             HtmlReport.render(scene_plan, incident: incident, explanation: explanation)

    assert html =~ ~s(data-incident-summary="true")
    assert html =~ ~s(data-explanation="true")
    assert html =~ ~s(data-stacktrace="true")
    assert html =~ ~s(data-evidence-type="log")
    assert html =~ ~s(data-evidence-type="journey_event")
    assert html =~ ~s(data-links="true")
    assert html =~ "billing_account_id=nil"
    assert html =~ "clicked upgrade"
    assert html =~ "Billing.Checkout.create_session"
  end

  test "renders screenshot, replay, and DOM visual evidence sections" do
    {:ok, screenshot_evidence} =
      ErrorStory.visual_evidence(:screenshot, %{
        source: :playwright,
        summary: "Checkout screenshot",
        url: "https://cdn.example/frame.png",
        route: "/checkout",
        viewport: %{width: 1280, height: 720}
      })

    {:ok, replay_evidence} =
      ErrorStory.visual_evidence(:replay, %{
        source: :logrocket,
        summary: "Checkout replay",
        replay_url: "https://app.logrocket.com/replay/123"
      })

    {:ok, dom_snapshot_evidence} =
      ErrorStory.visual_evidence(:dom_snapshot, %{
        source: :open_replay,
        summary: "Checkout DOM",
        dom_snapshot_id: "dom_123"
      })

    {:ok, incident} =
      Incident.new(
        title: "Checkout failed",
        evidence: [screenshot_evidence, replay_evidence, dom_snapshot_evidence]
      )

    scene_plan = %ScenePlan{
      title: "Checkout failed",
      scenes: [
        %{
          type: :browser_view,
          title: "Screenshot",
          caption: "Checkout screenshot",
          evidence: %{
            source: :playwright,
            evidence_type: :screenshot,
            route: "/checkout",
            viewport: %{width: 1280, height: 720},
            url: "https://cdn.example/frame.png"
          }
        }
      ]
    }

    assert {:ok, html} = HtmlReport.render(scene_plan, incident: incident)

    assert html =~ ~s(data-visual-evidence-type="screenshot")
    assert html =~ ~s(data-visual-evidence-type="replay")
    assert html =~ ~s(data-visual-evidence-type="dom_snapshot")
    assert html =~ ~s(<img src="https://cdn.example/frame.png")
    assert html =~ ~s(<a href="https://app.logrocket.com/replay/123">Open replay</a>)
    assert html =~ "dom_123"
    assert html =~ ~s(data-scene-type="browser_view")
    assert html =~ "Evidence Type"
    assert html =~ "/checkout"
  end

  test "escapes visual captions, highlights, and link attributes" do
    {:ok, screenshot_evidence} =
      ErrorStory.visual_evidence(:screenshot, %{
        source: :playwright,
        summary: "<script>alert(1)</script>",
        url: "https://cdn.example/frame.png?caption=\"bad\"",
        highlight: %{text: "<button>Pay</button>"}
      })

    {:ok, unsafe_replay_evidence} =
      ErrorStory.visual_evidence(:replay, %{
        summary: "Unsafe replay",
        replay_url: "javascript:alert(1)"
      })

    {:ok, incident} =
      Incident.new(
        title: "Checkout failed",
        links: [%{source: :unsafe, url: "javascript:alert(1)"}],
        evidence: [screenshot_evidence, unsafe_replay_evidence]
      )

    assert {:ok, html} =
             HtmlReport.render(%ScenePlan{title: "Checkout failed"}, incident: incident)

    assert html =~ "&lt;script&gt;alert(1)&lt;/script&gt;"
    assert html =~ "&lt;button&gt;Pay&lt;/button&gt;"
    assert html =~ ~s(src="https://cdn.example/frame.png?caption=&quot;bad&quot;")
    refute html =~ ~s|href="javascript:alert(1)"|
    assert String.contains?(html, "unsafe: javascript:alert(1)")
  end
end
