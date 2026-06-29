defmodule ErrorStory.DemoTaskTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  test "generates a local html report from the bundled fixture" do
    output_path = Path.expand("tmp/error_story_demo_report.html", File.cwd!())
    File.rm(output_path)
    Mix.Task.reenable("error_story.demo")

    output =
      capture_io(fn ->
        Mix.Task.run("error_story.demo")
      end)

    assert output =~ "Generated ErrorStory demo report"
    assert File.exists?(output_path)
    assert File.read!(output_path) =~ ~s(data-error-story-report="true")
  after
    "tmp/error_story_demo_report.html"
    |> Path.expand(File.cwd!())
    |> File.rm()
  end
end
