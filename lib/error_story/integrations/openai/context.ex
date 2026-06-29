defmodule ErrorStory.Integrations.OpenAI.Context do
  @moduledoc """
  OpenAI explanation provider.
  """

  @behaviour ErrorStory.Integrations.LLMProvider

  alias ErrorStory.Incident
  alias ErrorStory.Integrations.OpenAI.Api

  @impl ErrorStory.Integrations.LLMProvider
  @doc """
  Generates an incident explanation with OpenAI.

  ## Parameters

    * `incident` - normalized incident.
    * `opts` - optional `:model` and API options.

  ## Returns

  `{:ok, map()}` or `{:error, reason}`.
  """
  @spec explain_incident(Incident.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def explain_incident(%Incident{} = incident, opts \\ []) do
    model = Keyword.get(opts, :model, "gpt-4o-mini")

    request_body = %{
      model: model,
      messages: [
        %{
          role: "user",
          content: explanation_prompt(incident)
        }
      ],
      response_format: %{type: "json_object"}
    }

    with {:ok, response} <- Api.post_chat_completions(request_body, opts),
         {:ok, content} <- extract_content(response),
         {:ok, explanation} <- Jason.decode(content) do
      {:ok, explanation}
    end
  end

  defp explanation_prompt(%Incident{} = incident) do
    """
    Explain this production incident as JSON with keys developer_summary, product_summary, support_summary, likely_cause, next_checks.

    Incident:
    #{inspect(Map.take(incident, [:title, :service, :environment, :release, :route, :request_id, :trace_id]))}

    Evidence summaries:
    #{Enum.map_join(incident.evidence, "\n", &"- #{&1.source}: #{&1.summary}")}
    """
  end

  defp extract_content(%{"choices" => [%{"message" => %{"content" => content}} | _]})
       when is_binary(content) do
    {:ok, content}
  end

  defp extract_content(_response), do: {:error, :unexpected_openai_response}
end
