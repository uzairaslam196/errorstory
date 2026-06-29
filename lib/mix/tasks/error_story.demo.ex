defmodule Mix.Tasks.ErrorStory.Demo do
  @moduledoc """
  Generates a local ErrorStory HTML report from the bundled Sentry fixture.
  """

  use Mix.Task

  @shortdoc "Generate a demo ErrorStory report"

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    fixture_path = Path.expand("priv/fixtures/sentry_issue_webhook.json", File.cwd!())
    output_path = Path.expand("tmp/error_story_demo_report.html", File.cwd!())

    with {:ok, payload} <- read_json_fixture(fixture_path),
         {:ok, incident} <- ErrorStory.normalize(:sentry, payload, service: "billing"),
         {:ok, report} <- ErrorStory.report(incident),
         :ok <- File.mkdir_p(Path.dirname(output_path)),
         :ok <- File.write(output_path, report.artifact.content) do
      Mix.shell().info("Generated ErrorStory demo report: #{output_path}")
    else
      {:error, reason} ->
        Mix.raise("ErrorStory demo failed: #{inspect(reason)}")
    end
  end

  defp read_json_fixture(path) do
    with {:ok, body} <- File.read(path),
         {:ok, payload} <- Jason.decode(body) do
      {:ok, payload}
    end
  end
end
