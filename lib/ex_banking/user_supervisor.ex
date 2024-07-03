defmodule ExBanking.UserSupervisor do
  use DynamicSupervisor

  def start_link(_args) do
    DynamicSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_user(user) do
    DynamicSupervisor.start_child(__MODULE__, {ExBanking.UserServer, user})
  end
end