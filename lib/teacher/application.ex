defmodule Teacher.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    # List all child processes to be supervised
    children = [
      {Horde.Registry,
       [name: Teacher.CoinDataRegistry, keys: :unique, members: registry_members()]},
      {Horde.Supervisor,
       [
         name: Teacher.CoinDataSupervisor,
         strategy: :one_for_one,
         distribution_strategy: Horde.UniformQuorumDistribution,
         max_restarts: 100_000,
         max_seconds: 1,
         members: supervisor_members()
       ]},
      {Cluster.Supervisor, [Application.get_env(:libcluster, :topologies)]},
      {StateHandoff, []},
      %{
        id: Teacher.ClusterConnector,
        restart: :transient,
        start:
          {Task, :start_link,
           [
             fn ->
               #  Node.list()
               #  |> Enum.each(fn node ->
               #    IO.puts("setting members in Horde")

               #    Horde.Cluster.set_members(
               #      Teacher.CoinDataSupervisor,
               #      {Teacher.CoinDataSupervisor, node}
               #    )

               #    Horde.Cluster.set_members(
               #      Teacher.CoinDataRegistry,
               #      {Teacher.CoinDataRegistry, node}
               #    )
               Horde.Supervisor.wait_for_quorum(Teacher.CoinDataSupervisor, 30_000)

               Horde.Supervisor.start_child(
                 Teacher.CoinDataSupervisor,
                 Supervisor.child_spec({Teacher.CoinDataWorker, %{id: :btc}}, id: :btc)
               )

               Node.list()
               |> Enum.each(&StateHandoff.join(&1))

               #  Enum.each([:btc, :eth, :ltc], fn coin ->
               #    Horde.Supervisor.start_child(
               #      Teacher.CoinDataSupervisor,
               #      Supervisor.child_spec({Teacher.CoinDataWorker, %{id: coin}}, id: coin)
               #    )

               #    # add this line below
               #    #  :ok = StateHandoff.join(node)
               #  end)
             end
           ]}
      }
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Teacher.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp get_children() do
    Enum.map([:btc, :eth, :ltc], fn coin ->
      Supervisor.child_spec({Teacher.CoinDataWorker, %{id: coin}}, id: coin)
    end)
  end

  defp registry_members do
    [
      {Teacher.CoinDataRegistry, :"a@127.0.0.1"},
      {Teacher.CoinDataRegistry, :"b@127.0.0.1"},
      {Teacher.CoinDataRegistry, :"c@127.0.0.1"}
    ]
  end

  defp supervisor_members do
    [
      {Teacher.CoinDataSupervisor, :"a@127.0.0.1"},
      {Teacher.CoinDataSupervisor, :"b@127.0.0.1"},
      {Teacher.CoinDataSupervisor, :"c@127.0.0.1"}
    ]
  end
end
