defmodule ErrorStory.VisualEvidence do
  @moduledoc """
  Normalizes provider-neutral visual evidence.

  Host applications and provider adapters supply screenshots, replay links, or
  DOM snapshot references. This module keeps those references allowlisted and
  validates that visual evidence has a real source before scene planning or
  report rendering uses it.
  """

  alias ErrorStory.Evidence

  @types [:screenshot, :replay, :dom_snapshot]
  @fields [
    :route,
    :url,
    :file_path,
    :replay_url,
    :dom_snapshot_id,
    :viewport,
    :occurred_at,
    :highlight
  ]
  @reference_fields [:url, :file_path, :replay_url, :dom_snapshot_id, :route, :occurred_at]

  @doc """
  Builds normalized visual evidence.

  ## Parameters

    * `type` - `:screenshot`, `:replay`, or `:dom_snapshot`.
    * `attrs` - safe visual metadata.
    * `opts` - optional default `:source`, `:summary`, and visual metadata.

  ## Returns

  `{:ok, %ErrorStory.Evidence{}}` or `{:error, reason}`.
  """
  @spec build(atom(), map(), keyword()) :: {:ok, Evidence.t()} | {:error, term()}
  def build(type, attrs, opts \\ [])

  def build(type, attrs, opts) when type in @types and is_map(attrs) and is_list(opts) do
    visual = visual_attrs(attrs, opts)

    if referenced?(visual) do
      Evidence.new(
        type: type,
        source: value(attrs, :source, Keyword.get(opts, :source, :error_story)),
        occurred_at: value(attrs, :occurred_at, Keyword.get(opts, :occurred_at)),
        summary: value(attrs, :summary, Keyword.get(opts, :summary, "")),
        links: links(type, visual),
        visual: visual
      )
    else
      {:error, {:missing_visual_reference, type}}
    end
  end

  def build(type, attrs, _opts) when is_map(attrs) do
    {:error, {:unsupported_visual_evidence_type, type}}
  end

  def build(_type, _attrs, _opts), do: {:error, :invalid_visual_evidence_attrs}

  @doc """
  Returns true when evidence is a supported visual type with a real reference.
  """
  @spec referenced?(Evidence.t() | map() | nil) :: boolean()
  def referenced?(%Evidence{type: type, visual: visual}) when type in @types and is_map(visual) do
    referenced?(visual)
  end

  def referenced?(visual) when is_map(visual) do
    Enum.any?(@reference_fields, fn key ->
      visual
      |> value(key)
      |> blank?()
      |> Kernel.not()
    end)
  end

  def referenced?(_evidence_or_visual), do: false

  @doc """
  Reads atom or string keyed visual metadata.
  """
  @spec value(map(), atom(), term()) :: term()
  def value(values, key, default \\ nil)

  def value(values, key, default) when is_map(values) do
    Map.get(values, key, Map.get(values, to_string(key), default))
  end

  def value(_values, _key, default), do: default

  defp visual_attrs(attrs, opts) do
    @fields
    |> Enum.reduce(%{}, fn key, visual ->
      visual_value = value(attrs, key, Keyword.get(opts, key))

      if blank?(visual_value) do
        visual
      else
        Map.put(visual, key, visual_value)
      end
    end)
  end

  defp links(:screenshot, visual), do: visual |> value(:url) |> maybe_link(:screenshot)
  defp links(:replay, visual), do: visual |> value(:replay_url) |> maybe_link(:replay)
  defp links(:dom_snapshot, visual), do: visual |> value(:url) |> maybe_link(:dom_snapshot)

  defp maybe_link(value, _source) when value in [nil, ""], do: []
  defp maybe_link(value, source), do: [%{source: source, url: value}]

  defp blank?(nil), do: true
  defp blank?(""), do: true
  defp blank?(_value), do: false
end
