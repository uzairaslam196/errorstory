defmodule ErrorStory.IncidentTest do
  use ExUnit.Case, async: true

  alias ErrorStory.Evidence
  alias ErrorStory.Incident

  test "requires a title" do
    assert {:error, :missing_title} = Incident.new(source: :sentry)
  end

  test "normalizes evidence maps" do
    assert {:ok,
            %Incident{
              title: "checkout failed",
              evidence: [
                %Evidence{type: :log, source: :loki, summary: "billing_account_id nil"}
              ]
            }} =
             Incident.new(
               title: "checkout failed",
               evidence: [
                 %{type: :log, source: :loki, summary: "billing_account_id nil"}
               ]
             )
  end
end
