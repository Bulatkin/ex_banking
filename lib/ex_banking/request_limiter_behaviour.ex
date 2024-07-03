defmodule ExBanking.RequestLimiterBehaviour do
  @callback increment(String.t()) :: :ok | {:error, :too_many_requests_to_user}
  @callback decrement(String.t()) :: :ok
end
