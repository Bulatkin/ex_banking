defmodule ExBanking.RequestLimiter do
  use GenServer

  @behaviour ExBanking.RequestLimiterBehaviour
  @max_requests 10

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(state) do
    {:ok, state}
  end

  def increment(user) do
    GenServer.call(__MODULE__, {:increment, user})
  end

  def decrement(user) do
    GenServer.call(__MODULE__, {:decrement, user})
  end

  def handle_call({:increment, user}, _from, state) do
    count = Map.get(state, user, 0)

    if count >= @max_requests do
      {:reply, {:error, :too_many_requests_to_user}, state}
    else
      {:reply, :ok, Map.put(state, user, count + 1)}
    end
  end

  def handle_call({:decrement, user}, _from, state) do
    count = Map.get(state, user, 0)
    new_state = if count > 0, do: Map.put(state, user, count - 1), else: state

    {:reply, :ok, new_state}
  end
end
