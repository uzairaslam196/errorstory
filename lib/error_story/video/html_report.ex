defmodule ErrorStory.Video.HtmlReport do
  @moduledoc """
  Deterministic HTML report renderer for scene plans.

  This is the first renderer target for ErrorStory's video pipeline. It renders
  a grounded report from a scene plan without inventing missing browser views.
  """

  alias ErrorStory.Video.ScenePlan

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
           #{rendered_warnings}
           <section data-scenes="true">
     #{rendered_scenes}
           </section>
         </main>
       </body>
     </html>
     """}
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
    |> to_string()
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
  end
end
