defmodule ErrorStory.Video.HtmlReport do
  @moduledoc """
  Deterministic HTML report renderer for scene plans.

  This is the first renderer target for ErrorStory's video pipeline. It renders
  a grounded report from a scene plan without inventing missing browser views.
  """

  alias ErrorStory.Explanation
  alias ErrorStory.Incident
  alias ErrorStory.Video.ScenePlan

  @visual_reference_fields [:url, :file_path, :replay_url, :dom_snapshot_id, :route, :occurred_at]

  @doc """
  Renders a scene plan as an HTML document.

  ## Parameters

    * `scene_plan` - deterministic scene plan.
    * `opts` - optional renderer options.

  ## Returns

  `{:ok, html}`.
  """
  @spec render(ScenePlan.t(), keyword()) :: {:ok, String.t()}
  def render(%ScenePlan{} = scene_plan, opts \\ []) do
    rendered_scenes = Enum.map_join(scene_plan.scenes, "\n", &render_scene/1)
    rendered_warnings = render_warnings(scene_plan.warnings)
    title = Keyword.get(opts, :title, scene_plan.title)
    incident = Keyword.get(opts, :incident)
    explanation = Keyword.get(opts, :explanation)

    {:ok,
     """
     <!doctype html>
     <html>
       <head>
         <meta charset="utf-8">
         <title>#{escape(title)}</title>
       </head>
       <body>
         <main data-error-story-report="true">
           <h1>#{escape(scene_plan.title)}</h1>
           <p>Target duration: #{scene_plan.duration_target_seconds}s</p>
           #{render_incident_summary(incident)}
           #{render_explanation(explanation)}
           #{render_evidence_sections(incident)}
           #{rendered_warnings}
           <section data-scenes="true">
             <h2>Scene Plan</h2>
     #{rendered_scenes}
           </section>
         </main>
       </body>
     </html>
     """}
  end

  defp render_scene(%{type: :browser_view, evidence: evidence} = scene) do
    evidence = evidence || %{}

    """
    <article data-scene-type="browser_view">
      <h2>#{escape(scene.title)}</h2>
      <p>#{escape(scene.caption)}</p>
      <dl>
        #{definition("Evidence Type", evidence_value(evidence, :evidence_type))}
        #{definition("Source", evidence_value(evidence, :source))}
        #{definition("Route", evidence_value(evidence, :route))}
        #{definition("Viewport", evidence_value(evidence, :viewport))}
        #{definition("Timestamp", evidence_value(evidence, :timestamp))}
        #{definition("URL", evidence_value(evidence, :url))}
        #{definition("File Path", evidence_value(evidence, :file_path))}
        #{definition("Replay URL", evidence_value(evidence, :replay_url))}
        #{definition("DOM Snapshot ID", evidence_value(evidence, :dom_snapshot_id))}
        #{definition("Highlight", evidence_value(evidence, :highlight))}
      </dl>
    </article>
    """
  end

  defp render_scene(scene) do
    """
    <article data-scene-type="#{escape(to_string(scene.type))}">
      <h2>#{escape(scene.title)}</h2>
      <p>#{escape(scene.caption)}</p>
      <pre>#{escape(inspect(scene.evidence))}</pre>
    </article>
    """
  end

  defp render_incident_summary(%Incident{} = incident) do
    """
    <section data-incident-summary="true">
      <h2>Incident</h2>
      <dl>
        #{definition("Source", incident.source)}
        #{definition("Service", incident.service)}
        #{definition("Environment", incident.environment)}
        #{definition("Release", incident.release)}
        #{definition("Route", incident.route)}
        #{definition("Request ID", incident.request_id)}
        #{definition("Trace ID", incident.trace_id)}
        #{definition("User ID", incident.user_id)}
      </dl>
    </section>
    """
  end

  defp render_incident_summary(_incident), do: ""

  defp render_explanation(%Explanation{} = explanation) do
    """
    <section data-explanation="true">
      <h2>Explanation</h2>
      <h3>Developer</h3>
      <p>#{escape(explanation.developer_summary)}</p>
      <h3>Product</h3>
      <p>#{escape(explanation.product_summary)}</p>
      <h3>Support</h3>
      <p>#{escape(explanation.support_summary)}</p>
      <h3>Likely Cause</h3>
      <p>#{escape(explanation.likely_cause)}</p>
      <h3>Next Checks</h3>
      <ul>
        #{Enum.map_join(explanation.next_checks, "\n", &"<li>#{escape(&1)}</li>")}
      </ul>
    </section>
    """
  end

  defp render_explanation(_explanation), do: ""

  defp render_evidence_sections(%Incident{} = incident) do
    """
    #{render_stacktrace(incident.stacktrace)}
    #{render_visual_evidence_group("Screenshots", :screenshot, incident.evidence)}
    #{render_visual_evidence_group("Session Replays", :replay, incident.evidence)}
    #{render_visual_evidence_group("DOM Snapshots", :dom_snapshot, incident.evidence)}
    #{render_evidence_group("Logs", :log, incident.evidence)}
    #{render_evidence_group("User Journey", :journey_event, incident.evidence)}
    #{render_links(incident.links)}
    """
  end

  defp render_evidence_sections(_incident), do: ""

  defp render_stacktrace([]), do: ""

  defp render_stacktrace(stacktrace) do
    rendered_frames =
      Enum.map_join(stacktrace, "\n", fn frame ->
        module = Map.get(frame, "module") || Map.get(frame, :module)
        function = Map.get(frame, "function") || Map.get(frame, :function)
        filename = Map.get(frame, "filename") || Map.get(frame, :filename)
        line_number = Map.get(frame, "lineno") || Map.get(frame, :lineno)

        "<li><code>#{escape(module)}.#{escape(function)} #{escape(filename)}:#{escape(line_number)}</code></li>"
      end)

    """
    <section data-stacktrace="true">
      <h2>Stack Trace</h2>
      <ol>
        #{rendered_frames}
      </ol>
    </section>
    """
  end

  defp render_evidence_group(title, type, evidence) do
    evidence_items = Enum.filter(evidence, &(&1.type == type))

    if evidence_items == [] do
      ""
    else
      rendered_items =
        Enum.map_join(evidence_items, "\n", fn evidence_item ->
          "<li><strong>#{escape(evidence_item.source)}</strong>: #{escape(evidence_item.summary)}</li>"
        end)

      """
      <section data-evidence-type="#{escape(type)}">
        <h2>#{escape(title)}</h2>
        <ul>
          #{rendered_items}
        </ul>
      </section>
      """
    end
  end

  defp render_visual_evidence_group(title, type, evidence) do
    evidence_items = Enum.filter(evidence, &visual_evidence?(&1, type))

    if evidence_items == [] do
      ""
    else
      rendered_items =
        Enum.map_join(evidence_items, "\n", fn evidence_item ->
          render_visual_evidence_item(type, evidence_item)
        end)

      """
      <section data-visual-evidence-type="#{escape(type)}">
        <h2>#{escape(title)}</h2>
        <ul>
          #{rendered_items}
        </ul>
      </section>
      """
    end
  end

  defp render_visual_evidence_item(type, evidence_item) do
    visual = evidence_item.visual || %{}

    """
    <li>
      <strong>#{escape(evidence_item.source)}</strong>: #{escape(evidence_item.summary)}
      #{render_visual_preview(type, visual)}
      <dl>
        #{definition("Route", evidence_value(visual, :route))}
        #{definition("Viewport", evidence_value(visual, :viewport))}
        #{definition("Captured", evidence_item.occurred_at || evidence_value(visual, :occurred_at))}
        #{definition("URL", evidence_value(visual, :url))}
        #{definition("File Path", evidence_value(visual, :file_path))}
        #{definition("Replay URL", evidence_value(visual, :replay_url))}
        #{definition("DOM Snapshot ID", evidence_value(visual, :dom_snapshot_id))}
        #{definition("Highlight", evidence_value(visual, :highlight))}
      </dl>
    </li>
    """
  end

  defp render_visual_preview(:screenshot, visual) do
    case evidence_value(visual, :url) do
      url when is_binary(url) ->
        if safe_url?(url) do
          ~s(<figure><img src="#{escape(url)}" alt="Screenshot evidence preview"></figure>)
        else
          ""
        end

      _missing ->
        ""
    end
  end

  defp render_visual_preview(:replay, visual) do
    case evidence_value(visual, :replay_url) do
      replay_url when is_binary(replay_url) ->
        if safe_url?(replay_url) do
          ~s(<p><a href="#{escape(replay_url)}">Open replay</a></p>)
        else
          ""
        end

      _missing ->
        ""
    end
  end

  defp render_visual_preview(:dom_snapshot, visual) do
    case evidence_value(visual, :url) do
      url when is_binary(url) ->
        if safe_url?(url) do
          ~s(<p><a href="#{escape(url)}">Open DOM snapshot</a></p>)
        else
          ""
        end

      _missing ->
        ""
    end
  end

  defp render_visual_preview(_type, _visual), do: ""

  defp visual_evidence?(evidence_item, type) do
    evidence_item.type == type and is_map(evidence_item.visual) and
      has_visual_reference?(evidence_item.visual)
  end

  defp has_visual_reference?(visual) do
    Enum.any?(@visual_reference_fields, fn key ->
      visual
      |> evidence_value(key)
      |> blank?()
      |> Kernel.not()
    end)
  end

  defp render_links([]), do: ""

  defp render_links(links) do
    rendered_links =
      Enum.map_join(links, "\n", fn link ->
        source = Map.get(link, :source, Map.get(link, "source", "link"))
        url = Map.get(link, :url, Map.get(link, "url", ""))

        if safe_url?(url) do
          ~s(<li><a href="#{escape(url)}">#{escape(source)}</a></li>)
        else
          "<li>#{escape(source)}: #{escape(url)}</li>"
        end
      end)

    """
    <section data-links="true">
      <h2>Links</h2>
      <ul>
        #{rendered_links}
      </ul>
    </section>
    """
  end

  defp render_warnings([]), do: ""

  defp render_warnings(warnings) do
    rendered_warnings =
      Enum.map_join(warnings, "\n", fn warning ->
        "<li>#{escape(warning)}</li>"
      end)

    """
    <aside data-warnings="true">
      <h2>Warnings</h2>
      <ul>
    #{rendered_warnings}
      </ul>
    </aside>
    """
  end

  defp escape(value) do
    value
    |> value_to_string()
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
  end

  defp value_to_string(value) when is_binary(value), do: value
  defp value_to_string(value) when is_atom(value), do: Atom.to_string(value)
  defp value_to_string(%DateTime{} = value), do: DateTime.to_iso8601(value)
  defp value_to_string(value) when is_integer(value) or is_float(value), do: to_string(value)
  defp value_to_string(value), do: inspect(value)

  defp safe_url?(url) when is_binary(url) do
    case URI.parse(url) do
      %URI{scheme: scheme, host: host} when scheme in ["http", "https"] and is_binary(host) ->
        true

      _uri ->
        false
    end
  end

  defp safe_url?(_url), do: false

  defp evidence_value(values, key) when is_map(values) do
    Map.get(values, key, Map.get(values, to_string(key)))
  end

  defp evidence_value(_values, _key), do: nil

  defp blank?(nil), do: true
  defp blank?(""), do: true
  defp blank?(_value), do: false

  defp definition(_label, value) when value in [nil, ""], do: ""

  defp definition(label, value) do
    "<dt>#{escape(label)}</dt><dd>#{escape(value)}</dd>"
  end
end
