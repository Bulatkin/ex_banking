defmodule ExBanking do
  alias ExBanking.{UserSupervisor, UserServer}

  @spec create_user(user :: String.t()) :: :ok | {:error, :wrong_arguments | :user_already_exists}
  def create_user(user) when is_binary(user) do
    case UserSupervisor.start_user(user) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> {:error, :user_already_exists}
      _ -> {:error, :wrong_arguments}
    end
  end

  def create_user(_), do: {:error, :wrong_arguments}

  @spec deposit(user :: String.t(), amount :: number, currency :: String.t()) ::
          {:ok, new_balance :: number}
          | {:error, :wrong_arguments | :user_does_not_exist | :too_many_requests_to_user}
  def deposit(user, amount, currency) do
    with :ok <- validate_args(amount, currency),
         :ok <- ensure_user_exists(user),
         :ok <- request_limiter().increment(user) do
      response = UserServer.deposit(user, amount, currency)
      request_limiter().decrement(user)
      response
    else
      error -> error
    end
  end

  @spec withdraw(user :: String.t(), amount :: number, currency :: String.t()) ::
          {:ok, new_balance :: number}
          | {:error,
             :wrong_arguments
             | :user_does_not_exist
             | :not_enough_money
             | :too_many_requests_to_user}
  def withdraw(user, amount, currency) do
    with :ok <- validate_args(amount, currency),
         :ok <- ensure_user_exists(user),
         :ok <- request_limiter().increment(user) do
      response = UserServer.withdraw(user, amount, currency)
      request_limiter().decrement(user)
      response
    else
      error -> error
    end
  end

  @spec get_balance(user :: String.t(), currency :: String.t()) ::
          {:ok, balance :: number}
          | {:error, :wrong_arguments | :user_does_not_exist | :too_many_requests_to_user}
  def get_balance(user, currency) do
    with :ok <- validate_currency(currency),
         :ok <- ensure_user_exists(user),
         :ok <- request_limiter().increment(user) do
      response = UserServer.get_balance(user, currency)
      request_limiter().decrement(user)
      response
    else
      error -> error
    end
  end

  @spec send(
          from_user :: String.t(),
          to_user :: String.t(),
          amount :: number,
          currency :: String.t()
        ) ::
          {:ok, from_user_balance :: number, to_user_balance :: number}
          | {:error,
             :wrong_arguments
             | :not_enough_money
             | :sender_does_not_exist
             | :receiver_does_not_exist
             | :too_many_requests_to_sender
             | :too_many_requests_to_receiver}
  def send(from_user, to_user, amount, currency) do
    with :ok <- validate_args(amount, currency),
         :ok <- ensure_user_exists(from_user),
         :ok <- ensure_user_exists(to_user),
         :ok <- request_limiter().increment(from_user),
         :ok <- request_limiter().increment(to_user) do
      response = UserServer.send(from_user, to_user, amount, currency)
      request_limiter().decrement(from_user)
      request_limiter().decrement(to_user)
      response
    else
      error -> error
    end
  end

  defp request_limiter do
    Application.get_env(:ex_banking, :request_limiter)
  end

  defp ensure_user_exists(user) do
    case Registry.lookup(ExBanking.Registry, user) do
      [{_pid, _}] -> :ok
      _ -> {:error, :user_does_not_exist}
    end
  end

  defp validate_args(amount, currency) when is_number(amount) and is_binary(currency) do
    if amount > 0 do
      :ok
    else
      {:error, :wrong_arguments}
    end
  end

  defp validate_args(_, _), do: {:error, :wrong_arguments}

  defp validate_currency(currency) when is_binary(currency), do: :ok
  defp validate_currency(_), do: {:error, :wrong_arguments}
end
