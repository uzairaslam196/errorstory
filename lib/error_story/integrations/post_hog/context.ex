defmodule ErrorStory.Integrations.PostHog.Context do
  @moduledoc """
  PostHog user-journey evidence normalization.
  """

  @behaviour ErrorStory.Integrations.JourneyProvider

  alias ErrorStory.Evidence
  alias ErrorStory.Incident
  alias ErrorStory.Integrations.PostHog.Api

  @impl ErrorStory.Integrations.JourneyProvider
  @doc """
  Fetches PostHog journey evidence for an incident.

  ## Parameters

    * `incident` - normalized incident.
    * `opts` - PostHog options.

  ## Returns

  `{:ok, [%ErrorStory.Evidence{}]}` or `{:error, reason}`.
  """
  @spec fetch_journey(Incident.t(), keyword()) :: {:ok, [Evidence.t()]} | {:error, term()}
  def fetch_journey(%Incident{} = incident, opts \\ []) do
    with {:ok, distinct_id} <- distinct_id(incident),
         {:ok, response} <- Api.fetch_events(distinct_id, opts) do
      {:ok, normalize_events(response)}
    end
  end

  defp distinct_id(%Incident{user_id: user_id}) when is_binary(user_id), do: {:ok, user_id}

  defp distinct_id(%Incident{session_id: session_id}) when is_binary(session_id),
    do: {:ok, session_id}

  defp distinct_id(_incident), do: {:error, :missing_user_or_session_id}

  defp normalize_events(response) do
    response
    |> Map.get("results", [])
    |> Enum.map(fn event ->
      {:ok, evidence} =
        Evidence.new(
          type: :journey_event,
          source: :post_hog,
          summary: Map.get(event, "event", "PostHog event"),
          payload: event
        )

      evidence
    end)
  end
end
