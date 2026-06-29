defmodule ErrorStory.Explanation do
  @moduledoc """
  Provider-neutral incident explanation.

  The default explanation is deterministic and grounded in normalized incident
  fields. Host applications can pass an LLM provider through `ErrorStory.explain/2`
  when they want richer language.
  """

  alias ErrorStory.Incident

  @type t :: %__MODULE__{
          developer_summary: String.t(),
          product_summary: String.t(),
          support_summary: String.t(),
          likely_cause: String.t(),
          next_checks: [String.t()],
          evidence_count: non_neg_integer()
        }

  defstruct developer_summary: "",
            product_summary: "",
            support_summary: "",
            likely_cause: "",
            next_checks: [],
            evidence_count: 0

  @doc """
  Builds a deterministic explanation from a normalized incident.

  ## Parameters

    * `incident` - normalized incident.

  ## Returns

  `{:ok, %ErrorStory.Explanation{}}`.
  """
  @spec from_incident(Incident.t()) :: {:ok, t()}
  def from_incident(%Incident{} = incident) do
    {:ok,
     %__MODULE__{
       developer_summary: developer_summary(incident),
       product_summary: product_summary(incident),
       support_summary: support_summary(incident),
       likely_cause: likely_cause(incident),
       next_checks: next_checks(incident),
       evidence_count: length(incident.evidence)
     }}
  end

  @doc """
  Builds an explanation struct from a map returned by an LLM provider.

  ## Parameters

    * `attrs` - explanation attributes with atom or string keys.

  ## Returns

  `{:ok, %ErrorStory.Explanation{}}`.
  """
  @spec from_map(map()) :: {:ok, t()}
  def from_map(attrs) when is_map(attrs) do
    {:ok,
     %__MODULE__{
       developer_summary: get_attr(attrs, :developer_summary, ""),
       product_summary: get_attr(attrs, :product_summary, ""),
       support_summary: get_attr(attrs, :support_summary, ""),
       likely_cause: get_attr(attrs, :likely_cause, ""),
       next_checks: List.wrap(get_attr(attrs, :next_checks, [])),
       evidence_count: get_attr(attrs, :evidence_count, 0)
     }}
  end

  defp developer_summary(%Incident{} = incident) do
    [incident.title, scoped_identifier(incident)]
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.join(" ")
  end

  defp product_summary(%Incident{route: route}) when is_binary(route) do
    "A user-facing flow failed on #{route}."
  end

  defp product_summary(_incident), do: "A production error was captured."

  defp support_summary(%Incident{title: title}), do: "The issue is being investigated: #{title}."

  defp likely_cause(%Incident{evidence: []}) do
    "Insufficient evidence is attached; inspect related logs and user journey data."
  end

  defp likely_cause(%Incident{evidence: evidence}) do
    "Review the #{length(evidence)} attached evidence item(s), prioritizing errors, logs, and user journey events."
  end

  defp next_checks(%Incident{} = incident) do
    [
      request_check(incident),
      trace_check(incident),
      route_check(incident),
      "Compare first occurrence against the active release."
    ]
    |> Enum.reject(&is_nil/1)
  end

  defp scoped_identifier(%Incident{request_id: request_id}) when is_binary(request_id) do
    "Request id: #{request_id}."
  end

  defp scoped_identifier(%Incident{trace_id: trace_id}) when is_binary(trace_id) do
    "Trace id: #{trace_id}."
  end

  defp scoped_identifier(_incident), do: nil

  defp request_check(%Incident{request_id: request_id}) when is_binary(request_id) do
    "Fetch logs for request_id #{request_id}."
  end

  defp request_check(_incident), do: nil

  defp trace_check(%Incident{trace_id: trace_id}) when is_binary(trace_id) do
    "Inspect distributed trace #{trace_id}."
  end

  defp trace_check(_incident), do: nil

  defp route_check(%Incident{route: route}) when is_binary(route) do
    "Reproduce the user flow around #{route}."
  end

  defp route_check(_incident), do: nil

  defp get_attr(attrs, key, default) do
    Map.get(attrs, key, Map.get(attrs, to_string(key), default))
  end
end
