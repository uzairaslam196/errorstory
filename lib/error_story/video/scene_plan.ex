defmodule ErrorStory.Video.ScenePlan do
  @moduledoc """
  Deterministic scene plan for incident videos and reports.

  A scene plan references real evidence. Browser scenes are only created when
  screenshot, replay, or DOM evidence exists.
  """

  alias ErrorStory.Evidence
  alias ErrorStory.Incident
  alias ErrorStory.VisualEvidence

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

  defp visual_scenes(evidence_items) do
    evidence_items
    |> Enum.filter(&VisualEvidence.referenced?/1)
    |> Enum.map(fn %Evidence{} = evidence ->
      %{
        type: :browser_view,
        title: browser_scene_title(evidence),
        caption: evidence.summary,
        evidence: browser_scene_evidence(evidence, evidence_items)
      }
    end)
  end

  defp browser_scene_title(%Evidence{type: :screenshot}), do: "Screenshot"
  defp browser_scene_title(%Evidence{type: :replay}), do: "Session replay"
  defp browser_scene_title(%Evidence{type: :dom_snapshot}), do: "DOM snapshot"

  defp browser_scene_evidence(%Evidence{} = evidence, evidence_items) do
    visual = evidence.visual || %{}

    %{
      source: evidence.source,
      evidence_type: evidence.type,
      route: VisualEvidence.value(visual, :route),
      viewport: VisualEvidence.value(visual, :viewport),
      url: VisualEvidence.value(visual, :url),
      file_path: VisualEvidence.value(visual, :file_path),
      replay_url: VisualEvidence.value(visual, :replay_url),
      dom_snapshot_id: VisualEvidence.value(visual, :dom_snapshot_id),
      timestamp: evidence.occurred_at || VisualEvidence.value(visual, :occurred_at),
      highlight: VisualEvidence.value(visual, :highlight),
      caption: evidence.summary,
      related_journey_event: related_journey_event(evidence, evidence_items),
      links: evidence.links
    }
    |> reject_empty_values()
  end

  defp related_journey_event(%Evidence{} = visual_evidence, evidence_items) do
    visual_route = VisualEvidence.value(visual_evidence.visual || %{}, :route)

    evidence_items
    |> Enum.filter(&(&1.type == :journey_event))
    |> Enum.find(fn journey_evidence ->
      journey_route =
        Map.get(journey_evidence.payload, :route, Map.get(journey_evidence.payload, "route"))

      visual_route in [journey_route, nil]
    end)
    |> case do
      %Evidence{} = journey_evidence ->
        Map.take(journey_evidence, [:source, :summary, :occurred_at])

      nil ->
        nil
    end
  end

  defp reject_empty_values(values) do
    Map.reject(values, fn {_key, value} -> value in [nil, "", [], %{}] end)
  end

  defp root_cause_scene(%Incident{} = incident) do
    %{
      type: :technical_context,
      title: "Technical context",
      caption: technical_caption(incident),
      evidence: %{request_id: incident.request_id, trace_id: incident.trace_id}
    }
  end

  defp technical_caption(%Incident{request_id: request_id}) when is_binary(request_id) do
    "Use request_id #{request_id} to inspect related logs and traces."
  end

  defp technical_caption(%Incident{trace_id: trace_id}) when is_binary(trace_id) do
    "Use trace_id #{trace_id} to inspect related logs and traces."
  end

  defp technical_caption(_incident), do: "No request_id or trace_id was attached."
end
