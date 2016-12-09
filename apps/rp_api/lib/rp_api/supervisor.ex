defmodule RpAPI.Supervisor do
  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, :ok)
  end

  def init(:ok) do
    import Supervisor.Spec, warn: false
    RpAPI.Cache = :ets.new(RpAPI.Cache, [:set, :public, :named_table])

    # Define workers and child supervisors to be supervised
    children = [
      Plug.Adapters.Cowboy.child_spec(:http, RpAPI.Router, [], [port: 8080]),
      worker(RpAPI.Repo, [])
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: RpAPI.Supervisor]
    supervise(children, opts)
  end
end
