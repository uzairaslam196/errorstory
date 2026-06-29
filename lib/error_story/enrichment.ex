defmodule ErrorStory.Enrichment do
  @moduledoc """
  Adds provider evidence to normalized incidents.

  Enrichment accepts provider modules through options so host applications can
  decide which integrations to enable without ErrorStory owning their runtime
  pipeline or storage.
  """

  alias ErrorStory.Evidence
  alias ErrorStory.Incident

  @type provider_spec :: {module(), keyword()}

  @doc """
  Enriches an incident with evidence from configured providers.

  ## Parameters

    * `incident` - normalized incident.
    * `opts` - optional `:logs` and `:journey` provider specs in the form
      `{Module, provider_opts}`.

  ## Returns

  `{:ok, %ErrorStory.Incident{}}` when all configured providers succeed, or
  `{:error, {:enrichment_failed, failures, partial_incident}}`.
  """
  @spec run(Incident.t(), keyword()) :: {:ok, Incident.t()} | {:error, term()}
  def run(%Incident{} = incident, opts \\ []) do
    enrichment_steps = [
      {:logs, Keyword.get(opts, :logs), &fetch_logs/3},
      {:journey, Keyword.get(opts, :journey), &fetch_journey/3}
    ]

    {enriched_incident, failures} =
      Enum.reduce(enrichment_steps, {incident, []}, fn
        {_kind, nil, _fetch_fun}, {current_incident, failures} ->
          {current_incident, failures}

        {kind, provider_spec, fetch_fun}, {current_incident, failures} ->
          case fetch_fun.(provider_spec, current_incident, opts) do
            {:ok, evidence_items} ->
              next_incident = add_evidence_items(current_incident, evidence_items)
              {next_incident, failures}

            {:error, reason} ->
              {current_incident, failures ++ [{kind, reason}]}
          end
      end)

    case failures do
      [] -> {:ok, enriched_incident}
      _failures -> {:error, {:enrichment_failed, failures, enriched_incident}}
    end
  end

  defp fetch_logs({module, provider_opts}, %Incident{} = incident, _opts) do
    module.fetch_logs(incident, provider_opts)
  end

  defp fetch_journey({module, provider_opts}, %Incident{} = incident, _opts) do
    module.fetch_journey(incident, provider_opts)
  end

  defp add_evidence_items(%Incident{} = incident, evidence_items) when is_list(evidence_items) do
    Enum.reduce(evidence_items, incident, fn %Evidence{} = evidence, current_incident ->
      Incident.add_evidence(current_incident, evidence)
    end)
  end
end
