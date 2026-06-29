defmodule ErrorStory.TestSupport.FakeLogProvider do
  @behaviour ErrorStory.Integrations.LogProvider

  alias ErrorStory.Evidence
  alias ErrorStory.Incident

  @impl ErrorStory.Integrations.LogProvider
  def fetch_logs(%Incident{}, _opts) do
    {:ok, [%Evidence{type: :log, source: :loki, summary: "request failed"}]}
  end
end

defmodule ErrorStory.TestSupport.FailingJourneyProvider do
  @behaviour ErrorStory.Integrations.JourneyProvider

  alias ErrorStory.Incident

  @impl ErrorStory.Integrations.JourneyProvider
  def fetch_journey(%Incident{}, _opts) do
    {:error, :post_hog_unavailable}
  end
end

defmodule ErrorStory.TestSupport.FakeJourneyProvider do
  @behaviour ErrorStory.Integrations.JourneyProvider

  alias ErrorStory.Evidence
  alias ErrorStory.Incident

  @impl ErrorStory.Integrations.JourneyProvider
  def fetch_journey(%Incident{}, _opts) do
    {:ok, [%Evidence{type: :journey_event, source: :post_hog, summary: "clicked upgrade"}]}
  end
end

defmodule ErrorStory.TestSupport.FakeLLMProvider do
  @behaviour ErrorStory.Integrations.LLMProvider

  alias ErrorStory.Incident

  @impl ErrorStory.Integrations.LLMProvider
  def explain_incident(%Incident{}, _opts) do
    {:ok,
     %{
       "developer_summary" => "LLM developer summary",
       "product_summary" => "LLM product summary",
       "support_summary" => "LLM support summary",
       "likely_cause" => "LLM likely cause",
       "next_checks" => ["Check the checkout flow"]
     }}
  end
end
