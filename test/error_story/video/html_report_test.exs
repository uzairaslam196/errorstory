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
end
