defmodule ErrorStory.Integrations.LLMProvider do
  @moduledoc """
  Behaviour for LLM providers that explain normalized incidents.
  """

  alias ErrorStory.Incident

  @doc """
  Generates an explanation from a normalized incident.
  """
  @callback explain_incident(Incident.t(), keyword()) :: {:ok, map()} | {:error, term()}
end
