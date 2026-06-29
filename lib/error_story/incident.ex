defmodule ErrorStory.Incident do
  @moduledoc """
  Canonical normalized incident.

  Provider adapters translate raw payloads into this struct before any agent,
  explanation, or video logic runs.
  """

  alias ErrorStory.Evidence

  @type t :: %__MODULE__{
          id: String.t() | nil,
          source: atom(),
          title: String.t(),
          service: String.t() | nil,
          environment: String.t() | nil,
          release: String.t() | nil,
          occurred_at: DateTime.t() | nil,
          fingerprint: String.t() | nil,
          request_id: String.t() | nil,
          trace_id: String.t() | nil,
          user_id: String.t() | nil,
          session_id: String.t() | nil,
          route: String.t() | nil,
          error: term(),
          stacktrace: list(),
          metadata: map(),
          evidence: [Evidence.t()],
          links: [map()]
        }

  defstruct id: nil,
            source: :error_story,
            title: "",
            service: nil,
            environment: nil,
            release: nil,
            occurred_at: nil,
            fingerprint: nil,
            request_id: nil,
            trace_id: nil,
            user_id: nil,
            session_id: nil,
            route: nil,
            error: nil,
            stacktrace: [],
            metadata: %{},
            evidence: [],
            links: []

  @doc """
  Builds a normalized incident.

  ## Parameters

    * `attrs` - incident attributes.

  ## Returns

  `{:ok, %ErrorStory.Incident{}}` or `{:error, reason}`.
  """
  @spec new(map() | keyword()) :: {:ok, t()} | {:error, term()}
  def new(attrs) when is_list(attrs), do: attrs |> Map.new() |> new()

  def new(attrs) when is_map(attrs) do
    with {:ok, title} <- fetch_title(attrs),
         {:ok, evidence} <- normalize_evidence(Map.get(attrs, :evidence, [])) do
      {:ok,
       %__MODULE__{
         id: Map.get(attrs, :id),
         source: Map.get(attrs, :source, :error_story),
         title: title,
         service: Map.get(attrs, :service),
         environment: Map.get(attrs, :environment),
         release: Map.get(attrs, :release),
         occurred_at: Map.get(attrs, :occurred_at),
         fingerprint: Map.get(attrs, :fingerprint),
         request_id: Map.get(attrs, :request_id),
         trace_id: Map.get(attrs, :trace_id),
         user_id: Map.get(attrs, :user_id),
         session_id: Map.get(attrs, :session_id),
         route: Map.get(attrs, :route),
         error: Map.get(attrs, :error),
         stacktrace: Map.get(attrs, :stacktrace, []),
         metadata: Map.get(attrs, :metadata, %{}),
         evidence: evidence,
         links: Map.get(attrs, :links, [])
       }}
    end
  end

  @doc """
  Adds evidence to an incident.

  ## Parameters

    * `incident` - normalized incident.
    * `evidence` - evidence item.

  ## Returns

  Updated `%ErrorStory.Incident{}`.
  """
  @spec add_evidence(t(), Evidence.t()) :: t()
  def add_evidence(%__MODULE__{} = incident, %Evidence{} = evidence) do
    %{incident | evidence: incident.evidence ++ [evidence]}
  end

  defp fetch_title(attrs) do
    case Map.get(attrs, :title) do
      title when is_binary(title) and title != "" -> {:ok, title}
      _missing -> {:error, :missing_title}
    end
  end

  defp normalize_evidence(evidence_items) when is_list(evidence_items) do
    Enum.reduce_while(evidence_items, {:ok, []}, fn
      %Evidence{} = evidence, {:ok, collected} ->
        {:cont, {:ok, collected ++ [evidence]}}

      attrs, {:ok, collected} ->
        case Evidence.new(attrs) do
          {:ok, evidence} -> {:cont, {:ok, collected ++ [evidence]}}
          {:error, reason} -> {:halt, {:error, reason}}
        end
    end)
  end
end
