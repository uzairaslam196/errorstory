defmodule ErrorStory.Integrations.ErrorTracker do
  @moduledoc """
  Behaviour for providers that produce error incidents.
  """

  alias ErrorStory.Incident

  @doc """
  Normalizes a webhook payload into an incident.
  """
  @callback normalize_webhook(map(), keyword()) :: {:ok, Incident.t()} | {:error, term()}
end
