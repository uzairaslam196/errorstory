defmodule ErrorStory.ReportTest do
  use ExUnit.Case, async: true

  alias ErrorStory.{Explanation, Incident}
  alias ErrorStory.Report
  alias ErrorStory.TestSupport.{FailingJourneyProvider, FakeJourneyProvider, FakeLogProvider}
  alias ErrorStory.Video.ScenePlan

  test "builds a complete report from a normalized incident" do
    {:ok, incident} = Incident.new(title: "Checkout failed", request_id: "req_123")

    assert {:ok,
            %{
              incident: %Incident{evidence: [_log, _journey]},
              explanation: %Explanation{},
              scene_plan: %ScenePlan{},
              artifact: %{format: :html_report, content: html}
            }} =
             Report.build(incident,
               logs: {FakeLogProvider, []},
               journey: {FakeJourneyProvider, []}
             )

    assert html =~ ~s(data-error-story-report="true")
    assert html =~ "request failed"
    assert html =~ "clicked upgrade"
  end

  test "returns provider failures with a partial report" do
    {:ok, incident} = Incident.new(title: "Checkout failed", request_id: "req_123")

    assert {:error,
            {:report_failed, [journey: :post_hog_unavailable],
             %{
               incident: %Incident{evidence: [_log]},
               artifact: %{format: :html_report, content: html}
             }}} =
             Report.build(incident,
               logs: {FakeLogProvider, []},
               journey: {FailingJourneyProvider, []}
             )

    assert html =~ "request failed"
  end
end
