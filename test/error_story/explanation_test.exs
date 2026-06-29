defmodule ErrorStory.ExplanationTest do
  use ExUnit.Case, async: true

  alias ErrorStory.Explanation
  alias ErrorStory.Incident

  test "builds deterministic summaries from normalized incident fields" do
    {:ok, incident} =
      Incident.new(title: "Checkout failed", route: "/billing", request_id: "req_123")

    assert {:ok,
            %Explanation{
              developer_summary: "Checkout failed Request id: req_123.",
              product_summary: "A user-facing flow failed on /billing.",
              support_summary: "The issue is being investigated: Checkout failed."
            }} = Explanation.from_incident(incident)
  end

  test "normalizes llm provider maps with string keys" do
    assert {:ok,
            %Explanation{
              developer_summary: "Developer",
              product_summary: "Product",
              next_checks: ["A", "B"]
            }} =
             Explanation.from_map(%{
               "developer_summary" => "Developer",
               "product_summary" => "Product",
               "next_checks" => ["A", "B"]
             })
  end
end
