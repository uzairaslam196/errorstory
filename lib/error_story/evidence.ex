defmodule ErrorStory.Evidence do
  @moduledoc """
  Canonical evidence item used by agents and video/report planning.

  Evidence can originate from logs, product analytics, screenshots, replay
  links, stack traces, DOM snapshots, or provider metadata.
  """

  @type evidence_type ::
          :error
          | :log
          | :journey_event
          | :screenshot
          | :replay
          | :dom_snapshot
          | :release
          | :code_hint
          | :metadata

  @type t :: %__MODULE__{
          type: evidence_type(),
          source: atom(),
          occurred_at: DateTime.t() | nil,
          summary: String.t(),
          payload: map(),
          links: [map()],
          visual: map() | nil
        }

  @allowed_types [
    :error,
    :log,
    :journey_event,
    :screenshot,
    :replay,
    :dom_snapshot,
    :release,
    :code_hint,
    :metadata
  ]

  defstruct type: :metadata,
            source: :error_story,
            occurred_at: nil,
            summary: "",
            payload: %{},
            links: [],
            visual: nil

  @doc """
  Builds a canonical evidence item.

  ## Parameters

    * `attrs` - evidence attributes.

  ## Returns

  `{:ok, %ErrorStory.Evidence{}}` or `{:error, reason}`.
  """
  @spec new(map() | keyword()) :: {:ok, t()} | {:error, term()}
  def new(attrs) when is_list(attrs), do: attrs |> Map.new() |> new()

  def new(attrs) when is_map(attrs) do
    type = Map.get(attrs, :type, Map.get(attrs, "type", :metadata))

    if type in @allowed_types do
      {:ok,
       %__MODULE__{
         type: type,
         source: Map.get(attrs, :source, Map.get(attrs, "source", :error_story)),
         occurred_at: Map.get(attrs, :occurred_at, Map.get(attrs, "occurred_at")),
         summary: Map.get(attrs, :summary, Map.get(attrs, "summary", "")),
         payload: Map.get(attrs, :payload, Map.get(attrs, "payload", %{})),
         links: Map.get(attrs, :links, Map.get(attrs, "links", [])),
         visual: Map.get(attrs, :visual, Map.get(attrs, "visual"))
       }}
    else
      {:error, {:unsupported_evidence_type, type}}
    end
  end
end
