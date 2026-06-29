defmodule ErrorStory.Integrations.Loki.Context do
  @moduledoc """
  Loki log evidence normalization.
  """

  @behaviour ErrorStory.Integrations.LogProvider

  alias ErrorStory.Evidence
  alias ErrorStory.Incident
  alias ErrorStory.Integrations.Loki.Api

  @impl ErrorStory.Integrations.LogProvider
  @doc """
  Fetches Loki log evidence around an incident.

  ## Parameters

    * `incident` - normalized incident.
    * `opts` - Loki options.

  ## Returns

  `{:ok, [%ErrorStory.Evidence{}]}` or `{:error, reason}`.
  """
  @spec fetch_logs(Incident.t(), keyword()) :: {:ok, [Evidence.t()]} | {:error, term()}
  def fetch_logs(%Incident{} = incident, opts \\ []) do
    with {:ok, query} <- build_query(incident),
         {:ok, response} <- Api.query_range(query, opts) do
      {:ok, normalize_response(response)}
    end
  end

  defp build_query(%Incident{request_id: request_id}) when is_binary(request_id) do
    {:ok, ~s({request_id="#{request_id}"})}
  end

  defp build_query(%Incident{trace_id: trace_id}) when is_binary(trace_id) do
    {:ok, ~s({trace_id="#{trace_id}"})}
  end

  defp build_query(_incident), do: {:error, :missing_request_or_trace_id}

  defp normalize_response(response) do
    response
    |> get_in(["data", "result"])
    |> List.wrap()
    |> Enum.flat_map(&stream_values/1)
  end

  defp stream_values(%{"stream" => stream, "values" => values}) when is_list(values) do
    Enum.map(values, fn [_timestamp, line] ->
      {:ok, evidence} =
        Evidence.new(type: :log, source: :loki, summary: line, payload: %{stream: stream})

      evidence
    end)
  end

  defp stream_values(_result), do: []
end
