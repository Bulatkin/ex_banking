import Config

config :ex_banking, ExBanking.RequestLimiter, ExBanking.RequestLimiter

if function_exported?(Application, :ensure_all_started, 1) do
  Application.ensure_all_started(:ex_banking)
end

Application.put_env(:ex_banking, :request_limiter, ExBanking.RequestLimiter)
