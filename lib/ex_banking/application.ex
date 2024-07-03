defmodule ExBanking.Application do
  use Application

  def start(_type, _args) do
    children = [
      {Registry, keys: :unique, name: ExBanking.Registry},
      {DynamicSupervisor, strategy: :one_for_one, name: ExBanking.UserSupervisor},
      {ExBanking.RequestLimiter, []}
    ]

    opts = [strategy: :one_for_one, name: ExBanking.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
