defmodule ErrorStory.EnrichmentTest do
  use ExUnit.Case, async: true

  alias ErrorStory.Enrichment
  alias ErrorStory.Incident
  alias ErrorStory.TestSupport.FakeLogProvider

  test "does nothing when no providers are configured" do
    {:ok, incident} = Incident.new(title: "Checkout failed")

    assert {:ok, ^incident} = Enrichment.run(incident)
  end

  test "adds configured log evidence" do
    {:ok, incident} = Incident.new(title: "Checkout failed")

    assert {:ok, %Incident{evidence: [log_evidence]}} =
             Enrichment.run(incident, logs: {FakeLogProvider, []})

    assert log_evidence.type == :log
  end
end
