defmodule ErrorStory.Integrations.LogProvider do
  @moduledoc """
  Behaviour for providers that fetch logs around an incident.
  """

  alias ErrorStory.Evidence
  alias ErrorStory.Incident

  @doc """
  Fetches log evidence for an incident.
  """
  @callback fetch_logs(Incident.t(), keyword()) :: {:ok, [Evidence.t()]} | {:error, term()}
end
