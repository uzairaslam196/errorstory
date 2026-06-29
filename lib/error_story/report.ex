defmodule ErrorStory.Report do
  @moduledoc """
  End-to-end report orchestration for normalized incidents.

  The report pipeline stays host-neutral: it enriches with configured provider
  behaviours, explains the normalized incident, builds a scene plan, and renders
  an artifact without owning persistence, queues, or web framework concerns.
  """

  alias ErrorStory.Enrichment
  alias ErrorStory.Explanation
  alias ErrorStory.Incident
  alias ErrorStory.Video.HtmlReport
  alias ErrorStory.Video.ScenePlan

  @type artifact :: %{format: :html_report, content: String.t()}

  @type t :: %{
          incident: Incident.t(),
          explanation: Explanation.t(),
          scene_plan: ScenePlan.t(),
          artifact: artifact()
        }

  @doc """
  Builds a report from a normalized incident.

  ## Parameters

    * `incident` - normalized incident.
    * `opts` - optional `:logs`, `:journey`, `:llm`, and renderer options.

  ## Returns

  `{:ok, report}` or
  `{:error, {:report_failed, failures, partial_report}}` when enrichment fails.
  """
  @spec build(Incident.t(), keyword()) :: {:ok, t()} | {:error, term()}
  def build(%Incident{} = incident, opts \\ []) do
    case Enrichment.run(incident, opts) do
      {:ok, enriched_incident} ->
        build_report(enriched_incident, opts)

      {:error, {:enrichment_failed, failures, partial_incident}} ->
        with {:ok, partial_report} <- build_report(partial_incident, opts) do
          {:error, {:report_failed, failures, partial_report}}
        end
    end
  end

  defp build_report(%Incident{} = incident, opts) do
    with {:ok, explanation} <- explain(incident, opts),
         {:ok, scene_plan} <- ScenePlan.from_incident(incident, opts),
         {:ok, html} <-
           HtmlReport.render(scene_plan, incident: incident, explanation: explanation) do
      {:ok,
       %{
         incident: incident,
         explanation: explanation,
         scene_plan: scene_plan,
         artifact: %{format: :html_report, content: html}
       }}
    end
  end

  defp explain(%Incident{} = incident, opts) do
    case Keyword.get(opts, :llm) do
      nil ->
        Explanation.from_incident(incident)

      {module, provider_opts} ->
        with {:ok, explanation_attrs} <- module.explain_incident(incident, provider_opts) do
          Explanation.from_map(explanation_attrs)
        end
    end
  end
end
