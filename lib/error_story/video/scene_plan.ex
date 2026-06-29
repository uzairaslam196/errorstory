defmodule ErrorStory.Video.ScenePlan do
  @moduledoc """
  Deterministic scene plan for incident videos and reports.

  A scene plan references real evidence. Browser scenes are only created when
  screenshot, replay, or DOM evidence exists.
  """

  alias ErrorStory.Evidence
  alias ErrorStory.Incident

  @type scene :: %{
          type: atom(),
          title: String.t(),
          caption: String.t(),
          evidence: map() | nil
        }

  @type t :: %__MODULE__{
          title: String.t(),
          duration_target_seconds: pos_integer(),
          scenes: [scene()],
          warnings: [String.t()]
        }

  defstruct title: "",
            duration_target_seconds: 60,
            scenes: [],
            warnings: []

  @doc """
  Builds a scene plan from a normalized incident.

  ## Parameters

    * `incident` - normalized incident.
    * `opts` - optional `:duration_target_seconds`.

  ## Returns

  `{:ok, %ErrorStory.Video.ScenePlan{}}`.
  """
  @spec from_incident(Incident.t(), keyword()) :: {:ok, t()}
  def from_incident(%Incident{} = incident, opts \\ []) do
    visual_scenes = visual_scenes(incident.evidence)

    warnings =
      if visual_scenes == [] do
        ["No visual evidence was available; browser scenes were not generated."]
      else
        []
      end

    scenes =
      [
        summary_scene(incident),
        timeline_scene(incident.evidence)
      ] ++ visual_scenes ++ [root_cause_scene(incident)]

    {:ok,
     %__MODULE__{
       title: incident.title,
       duration_target_seconds: Keyword.get(opts, :duration_target_seconds, 60),
       scenes: scenes,
       warnings: warnings
     }}
  end

  defp summary_scene(%Incident{} = incident) do
    %{
      type: :summary,
      title: "Incident summary",
      caption: incident.title,
      evidence: %{source: incident.source, incident_id: incident.id}
    }
  end

  defp timeline_scene(evidence) do
    %{
      type: :timeline,
      title: "Evidence timeline",
      caption: "#{length(evidence)} evidence item(s) collected",
      evidence: %{items: Enum.map(evidence, &Map.take(&1, [:type, :source, :summary]))}
    }
  end

  defp visual_scenes(evidence) do
    evidence
    |> Enum.filter(&visual_evidence?/1)
    |> Enum.map(fn %Evidence{} = evidence ->
      %{
        type: :browser_view,
        title: "User-facing view",
        caption: evidence.summary,
        evidence: %{source: evidence.source, visual: evidence.visual, links: evidence.links}
      }
    end)
  end

  defp root_cause_scene(%Incident{} = incident) do
    %{
      type: :technical_context,
      title: "Technical context",
      caption: technical_caption(incident),
      evidence: %{request_id: incident.request_id, trace_id: incident.trace_id}
    }
  end

  defp visual_evidence?(%Evidence{type: type, visual: visual})
       when type in [:screenshot, :replay, :dom_snapshot] and is_map(visual) do
    true
  end

  defp visual_evidence?(_evidence), do: false

  defp technical_caption(%Incident{request_id: request_id}) when is_binary(request_id) do
    "Use request_id #{request_id} to inspect related logs and traces."
  end

  defp technical_caption(%Incident{trace_id: trace_id}) when is_binary(trace_id) do
    "Use trace_id #{trace_id} to inspect related logs and traces."
  end

  defp technical_caption(_incident), do: "No request_id or trace_id was attached."
end
