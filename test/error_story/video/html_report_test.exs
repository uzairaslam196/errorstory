defmodule ErrorStory.Video.HtmlReportTest do
  use ExUnit.Case, async: true

  alias ErrorStory.Video.HtmlReport
  alias ErrorStory.Video.ScenePlan

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
end
