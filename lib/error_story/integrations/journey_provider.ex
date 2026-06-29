defmodule ErrorStory.Integrations.JourneyProvider do
  @moduledoc """
  Behaviour for providers that fetch user journey evidence.
  """

  alias ErrorStory.Evidence
  alias ErrorStory.Incident

  @doc """
  Fetches user journey evidence for an incident.
  """
  @callback fetch_journey(Incident.t(), keyword()) :: {:ok, [Evidence.t()]} | {:error, term()}
end
