defmodule ErrorStory do
  @moduledoc """
  Public entrypoint for ErrorStory.

  ErrorStory normalizes production-error evidence from provider adapters into
  stable incident structs. Explanation and video modules consume those structs
  instead of raw Sentry, Loki, PostHog, or LLM payloads.
  """

  alias ErrorStory.Enrichment
  alias ErrorStory.Evidence
  alias ErrorStory.Explanation
  alias ErrorStory.Incident
  alias ErrorStory.Integrations.Sentry
  alias ErrorStory.Report
  alias ErrorStory.Video.HtmlReport
  alias ErrorStory.Video.ScenePlan

  @visual_evidence_types [:screenshot, :replay, :dom_snapshot]
  @visual_evidence_fields [
    :route,
    :url,
    :file_path,
    :replay_url,
    :dom_snapshot_id,
    :viewport,
    :occurred_at,
    :highlight
  ]
  @visual_reference_fields [:url, :file_path, :replay_url, :dom_snapshot_id, :route, :occurred_at]

  @doc """
  Captures an exception into a normalized incident.

  ## Parameters

    * `exception` - an exception struct or term.
    * `opts` - optional metadata such as `:source`, `:service`, `:environment`,
      `:stacktrace`, `:request_id`, and `:trace_id`.

  ## Returns

  `{:ok, %ErrorStory.Incident{}}` or `{:error, reason}`.
  """
  @spec capture(Exception.t() | term(), keyword()) :: {:ok, Incident.t()} | {:error, term()}
  def capture(exception, opts \\ []) do
    attrs =
      opts
      |> Map.new()
      |> Map.put_new(:source, :error_story)
      |> Map.put(:title, exception_title(exception))
      |> Map.put(:error, exception)

    Incident.new(attrs)
  end

  @doc """
  Keeps only explicitly allowed snapshot attributes.

  ## Parameters

    * `name` - snapshot name, such as `:billing_checkout`.
    * `attrs` - candidate snapshot attributes.
    * `opts` - `:allow` list of atom or string keys.

  ## Returns

  `{:ok, %{name: atom(), attrs: map()}}`.
  """
  @spec snapshot(atom(), map(), keyword()) :: {:ok, %{name: atom(), attrs: map()}}
  def snapshot(name, attrs, opts \\ []) when is_atom(name) and is_map(attrs) do
    allowed_keys = Keyword.get(opts, :allow, [])
    allowed_key_strings = Enum.map(allowed_keys, &to_string/1)

    safe_attrs =
      Map.filter(attrs, fn {key, _value} ->
        to_string(key) in allowed_key_strings
      end)

    {:ok, %{name: name, attrs: safe_attrs}}
  end

  @doc """
  Builds a normalized breadcrumb map.

  ## Parameters

    * `name` - breadcrumb name.
    * `attrs` - small safe metadata map.
    * `opts` - optional `:occurred_at` timestamp.

  ## Returns

  `{:ok, map()}`.
  """
  @spec breadcrumb(atom(), map(), keyword()) :: {:ok, map()}
  def breadcrumb(name, attrs \\ %{}, opts \\ []) when is_atom(name) and is_map(attrs) do
    {:ok,
     %{
       name: name,
       attrs: attrs,
       occurred_at: Keyword.get(opts, :occurred_at, DateTime.utc_now())
     }}
  end

  @doc """
  Builds normalized visual evidence for screenshots, replays, and DOM snapshots.

  ErrorStory does not capture screenshots or record sessions itself. Host apps
  and provider adapters pass safe references such as screenshot URLs, replay
  URLs, file paths, DOM snapshot ids, routes, or capture timestamps.

  ## Parameters

    * `type` - `:screenshot`, `:replay`, or `:dom_snapshot`.
    * `attrs` - safe visual metadata. Accepted fields are `:source`,
      `:summary`, `:route`, `:url`, `:file_path`, `:replay_url`,
      `:dom_snapshot_id`, `:viewport`, `:occurred_at`, and `:highlight`.
    * `opts` - optional default `:source`, `:summary`, and `:occurred_at`.

  ## Returns

  `{:ok, %ErrorStory.Evidence{}}` or `{:error, reason}`.
  """
  @spec visual_evidence(atom(), map(), keyword()) :: {:ok, Evidence.t()} | {:error, term()}
  def visual_evidence(type, attrs, opts \\ [])

  def visual_evidence(type, attrs, opts)
      when type in @visual_evidence_types and is_map(attrs) and is_list(opts) do
    visual = visual_attrs(attrs, opts)

    if has_visual_reference?(visual) do
      Evidence.new(
        type: type,
        source: attr(attrs, :source, Keyword.get(opts, :source, :error_story)),
        occurred_at: attr(attrs, :occurred_at, Keyword.get(opts, :occurred_at)),
        summary: attr(attrs, :summary, Keyword.get(opts, :summary, "")),
        links: visual_links(type, visual),
        visual: visual
      )
    else
      {:error, {:missing_visual_reference, type}}
    end
  end

  def visual_evidence(type, attrs, _opts) when is_map(attrs) do
    {:error, {:unsupported_visual_evidence_type, type}}
  end

  def visual_evidence(_type, _attrs, _opts), do: {:error, :invalid_visual_evidence_attrs}

  @doc """
  Normalizes a provider payload into an incident.

  ## Parameters

    * `source` - provider source atom.
    * `payload` - raw provider payload.
    * `opts` - provider-specific options.

  ## Returns

  `{:ok, %ErrorStory.Incident{}}` or `{:error, reason}`.
  """
  @spec normalize(atom(), map(), keyword()) :: {:ok, Incident.t()} | {:error, term()}
  def normalize(source, payload, opts \\ [])

  def normalize(:sentry, payload, opts) when is_map(payload) do
    Sentry.Context.normalize_webhook(payload, opts)
  end

  def normalize(source, _payload, _opts) do
    {:error, {:unsupported_source, source}}
  end

  @doc """
  Enriches a normalized incident with provider evidence.

  ## Parameters

    * `incident` - normalized incident.
    * `opts` - optional provider specs such as `logs: {Module, opts}` and
      `journey: {Module, opts}`.

  ## Returns

  `{:ok, %ErrorStory.Incident{}}` or
  `{:error, {:enrichment_failed, failures, partial_incident}}`.
  """
  @spec enrich(Incident.t(), keyword()) :: {:ok, Incident.t()} | {:error, term()}
  def enrich(%Incident{} = incident, opts \\ []) do
    Enrichment.run(incident, opts)
  end

  @doc """
  Explains a normalized incident.

  ## Parameters

    * `incident` - normalized incident.
    * `opts` - optional `:llm` provider spec in the form `{Module, opts}`.

  ## Returns

  `{:ok, %ErrorStory.Explanation{}}` or `{:error, reason}`.
  """
  @spec explain(Incident.t(), keyword()) :: {:ok, Explanation.t()} | {:error, term()}
  def explain(%Incident{} = incident, opts \\ []) do
    case Keyword.get(opts, :llm) do
      nil ->
        Explanation.from_incident(incident)

      {module, provider_opts} ->
        with {:ok, explanation_attrs} <- module.explain_incident(incident, provider_opts) do
          Explanation.from_map(explanation_attrs)
        end
    end
  end

  @doc """
  Produces a deterministic video/report scene plan for an incident.

  ## Parameters

    * `incident` - normalized incident.
    * `opts` - scene-planning options.

  ## Returns

  `{:ok, %ErrorStory.Video.ScenePlan{}}`.
  """
  @spec scene_plan(Incident.t(), keyword()) :: {:ok, ScenePlan.t()} | {:error, term()}
  def scene_plan(%Incident{} = incident, opts \\ []) do
    ScenePlan.from_incident(incident, opts)
  end

  @doc """
  Produces a deterministic video scene plan for an incident.

  This is an alias for `scene_plan/2` using the public name from the video
  pipeline. The returned plan references real evidence only.

  ## Parameters

    * `incident` - normalized incident.
    * `opts` - scene-planning options.

  ## Returns

  `{:ok, %ErrorStory.Video.ScenePlan{}}`.
  """
  @spec video_plan(Incident.t(), keyword()) :: {:ok, ScenePlan.t()} | {:error, term()}
  def video_plan(%Incident{} = incident, opts \\ []) do
    scene_plan(incident, opts)
  end

  @doc """
  Renders an incident scene plan as an HTML report.

  ## Parameters

    * `scene_plan` - deterministic scene plan.
    * `opts` - render options.

  ## Returns

  `{:ok, html}`.
  """
  @spec render_report(ScenePlan.t(), keyword()) :: {:ok, String.t()}
  def render_report(%ScenePlan{} = scene_plan, opts \\ []) do
    HtmlReport.render(scene_plan, opts)
  end

  @doc """
  Renders the current video artifact for a scene plan.

  The v1 renderer returns an evidence-grounded HTML report artifact. MP4/WebM
  encoding can be added later as another deterministic renderer without
  changing incident or provider contracts.

  ## Parameters

    * `scene_plan` - deterministic scene plan.
    * `opts` - render options.

  ## Returns

  `{:ok, %{format: :html_report, content: html}}`.
  """
  @spec render_video(ScenePlan.t(), keyword()) ::
          {:ok, %{format: :html_report, content: String.t()}}
  def render_video(%ScenePlan{} = scene_plan, opts \\ []) do
    with {:ok, html} <- render_report(scene_plan, opts) do
      {:ok, %{format: :html_report, content: html}}
    end
  end

  @doc """
  Builds a complete report from a normalized incident.

  ## Parameters

    * `incident` - normalized incident.
    * `opts` - optional `:logs`, `:journey`, and `:llm` provider specs.

  ## Returns

  `{:ok, %{incident:, explanation:, scene_plan:, artifact:}}` or a structured
  error containing provider failures and a partial report.
  """
  @spec report(Incident.t(), keyword()) :: {:ok, Report.t()} | {:error, term()}
  def report(%Incident{} = incident, opts \\ []) do
    Report.build(incident, opts)
  end

  defp exception_title(%_struct{} = exception) do
    Exception.message(exception)
  rescue
    _error -> inspect(exception)
  end

  defp exception_title(exception), do: inspect(exception)

  defp visual_attrs(attrs, opts) do
    @visual_evidence_fields
    |> Enum.reduce(%{}, fn key, visual ->
      value = attr(attrs, key, Keyword.get(opts, key))

      if blank?(value) do
        visual
      else
        Map.put(visual, key, value)
      end
    end)
  end

  defp has_visual_reference?(visual) do
    Enum.any?(@visual_reference_fields, fn key ->
      visual
      |> Map.get(key)
      |> blank?()
      |> Kernel.not()
    end)
  end

  defp visual_links(:screenshot, visual) do
    visual
    |> Map.get(:url)
    |> maybe_visual_link(:screenshot)
  end

  defp visual_links(:replay, visual) do
    visual
    |> Map.get(:replay_url)
    |> maybe_visual_link(:replay)
  end

  defp visual_links(:dom_snapshot, visual) do
    visual
    |> Map.get(:url)
    |> maybe_visual_link(:dom_snapshot)
  end

  defp maybe_visual_link(value, _source) when value in [nil, ""], do: []

  defp maybe_visual_link(value, source), do: [%{source: source, url: value}]

  defp attr(attrs, key, default) do
    Map.get(attrs, key, Map.get(attrs, to_string(key), default))
  end

  defp blank?(nil), do: true
  defp blank?(""), do: true
  defp blank?(_value), do: false
end
