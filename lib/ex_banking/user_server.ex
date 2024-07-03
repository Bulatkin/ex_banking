defmodule ExBanking.UserServer do
  use GenServer
  alias Decimal, as: D

  def start_link(user) do
    GenServer.start_link(__MODULE__, %{user: user, balances: %{}}, name: via_tuple(user))
  end

  def init(state) do
    {:ok, state}
  end

  def deposit(user, amount, currency) do
    if valid_amount?(amount) and valid_currency?(currency) do
      GenServer.call(via_tuple(user), {:deposit, D.new(to_string(amount)), currency})
    else
      {:error, :wrong_arguments}
    end
  end

  def withdraw(user, amount, currency) do
    if valid_amount?(amount) and valid_currency?(currency) do
      GenServer.call(via_tuple(user), {:withdraw, D.new(to_string(amount)), currency})
    else
      {:error, :wrong_arguments}
    end
  end

  def get_balance(user, currency) do
    if valid_currency?(currency) do
      GenServer.call(via_tuple(user), {:get_balance, currency})
    else
      {:error, :wrong_arguments}
    end
  end

  def send(from_user, to_user, amount, currency) do
    if from_user == to_user do
      {:error, :wrong_arguments}
    else
      if valid_amount?(amount) and valid_currency?(currency) do
        case GenServer.call(via_tuple(from_user), {:withdraw, D.new(to_string(amount)), currency}) do
          {:ok, from_balance} ->
            case GenServer.call(
                   via_tuple(to_user),
                   {:deposit, D.new(to_string(amount)), currency}
                 ) do
              {:ok, to_balance} ->
                {:ok, from_balance, to_balance}

              error ->
                # Revert withdrawal if deposit fails
                GenServer.call(
                  via_tuple(from_user),
                  {:deposit, D.new(to_string(amount)), currency}
                )

                error
            end

          error ->
            error
        end
      else
        {:error, :wrong_arguments}
      end
    end
  end

  def handle_call({:deposit, amount, currency}, _from, state) do
    new_balances = Map.update(state.balances, currency, amount, &D.add(&1, amount))

    {:reply, {:ok, D.to_float(new_balances[currency]) |> Float.round(2)},
     %{state | balances: new_balances}}
  end

  def handle_call({:withdraw, amount, currency}, _from, state) do
    current_balance = Map.get(state.balances, currency, D.new(0))

    if D.compare(current_balance, amount) == :lt do
      {:reply, {:error, :not_enough_money}, state}
    else
      new_balances = Map.put(state.balances, currency, D.sub(current_balance, amount))

      {:reply, {:ok, D.to_float(new_balances[currency]) |> Float.round(2)},
       %{state | balances: new_balances}}
    end
  end

  def handle_call({:get_balance, currency}, _from, state) do
    balance = Map.get(state.balances, currency, D.new(0))
    {:reply, {:ok, D.to_float(balance) |> Float.round(2)}, state}
  end

  defp via_tuple(user), do: {:via, Registry, {ExBanking.Registry, user}}

  defp valid_amount?(amount), do: is_number(amount) and amount >= 0
  defp valid_currency?(currency), do: is_binary(currency)
end
