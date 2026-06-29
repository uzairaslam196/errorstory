defmodule ErrorStory.Integrations.Sentry.Api do
  @moduledoc """
  Raw Sentry API and webhook-signature helpers.

  This module owns Sentry auth, base URL, and signature verification. It does
  not translate Sentry payloads into ErrorStory domain structs.
  """

  alias ErrorStory.Config
  alias ErrorStory.Request

  @base_url "https://sentry.io/api/0/"

  @doc """
  Builds a Sentry API client.

  ## Parameters

    * `opts` - optional client overrides.

  ## Returns

  A `%Req.Request{}`.
  """
  @spec client(keyword()) :: Req.Request.t()
  def client(opts \\ []) do
    auth_token = Keyword.get(opts, :auth_token) || Config.get(:sentry_auth_token)

    headers =
      if auth_token do
        [{"authorization", "Bearer #{auth_token}"}]
      else
        []
      end

    Request.new(base_url: @base_url, headers: headers)
  end

  @doc """
  Verifies a Sentry webhook signature using HMAC-SHA256.

  ## Parameters

    * `raw_body` - unparsed webhook body.
    * `signature` - signature header value.
    * `secret` - webhook client secret.

  ## Returns

  `:ok` or `{:error, :invalid_signature}`.
  """
  @spec verify_event_signature(binary(), binary() | nil, binary() | nil) ::
          :ok | {:error, :invalid_signature}
  def verify_event_signature(raw_body, signature, secret)
      when is_binary(raw_body) and is_binary(signature) and is_binary(secret) do
    expected_signature =
      :hmac
      |> :crypto.mac(:sha256, secret, raw_body)
      |> Base.encode16(case: :lower)

    if secure_compare(expected_signature, signature) do
      :ok
    else
      {:error, :invalid_signature}
    end
  rescue
    _error -> {:error, :invalid_signature}
  end

  def verify_event_signature(_raw_body, _signature, _secret), do: {:error, :invalid_signature}

  defp secure_compare(left, right) when byte_size(left) == byte_size(right) do
    left
    |> :crypto.exor(right)
    |> :binary.bin_to_list()
    |> Enum.reduce(0, fn byte, acc -> Bitwise.bor(byte, acc) end)
    |> Kernel.==(0)
  end

  defp secure_compare(_left, _right), do: false
end
