defmodule ErrorStory.Config do
  @moduledoc """
  Configuration helpers for ErrorStory.

  Supports literal values and `{:system, env_var}` tuples so host
  applications can keep API keys in environment variables.
  """

  @doc """
  Fetches an ErrorStory application config value.

  ## Parameters

    * `key` - config key under `:error_story`.
    * `default` - fallback value.

  ## Returns

  The configured value, environment value, or default.
  """
  @spec get(atom(), term()) :: term()
  def get(key, default \\ nil) when is_atom(key) do
    :error_story
    |> Application.get_env(key, default)
    |> resolve_value()
  end

  @doc """
  Fetches a required ErrorStory application config value.

  ## Parameters

    * `key` - config key under `:error_story`.

  ## Returns

  The configured value or raises when missing.
  """
  @spec fetch!(atom()) :: term()
  def fetch!(key) when is_atom(key) do
    case get(key) do
      nil -> raise ArgumentError, "missing ErrorStory config #{inspect(key)}"
      "" -> raise ArgumentError, "missing ErrorStory config #{inspect(key)}"
      value -> value
    end
  end

  @doc """
  Resolves a literal or environment-backed config value.

  ## Parameters

    * `value` - literal value, `{:system, env_var}`, or
      `{:system, env_var, default}`.

  ## Returns

  The resolved value.
  """
  @spec resolve_value(term()) :: term()
  def resolve_value({:system, env_var}) when is_binary(env_var), do: System.get_env(env_var)

  def resolve_value({:system, env_var, default}) when is_binary(env_var) do
    System.get_env(env_var) || default
  end

  def resolve_value(value), do: value
end
