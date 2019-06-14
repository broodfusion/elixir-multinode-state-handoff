defmodule Example.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    # List all child processes to be supervised

    topologies = [
      local: [
        # strategy: LibCluster.LocalStrategy
        strategy: Cluster.Strategy.Gossip
      ]
    ]

    children = [
      # {Example.StateHandoff, []},
      {Horde.Registry, [name: Example.MyRegistry, keys: :unique, members: registry_members()]},
      {Horde.Supervisor,
       [
         name: Example.MySupervisor,
         strategy: :one_for_one,
         #  distribution_strategy: Horde.UniformQuorumDistribution,
         #  max_restarts: 100_000,
         #  max_seconds: 1,
         members: supervisor_members()
       ]},
      {Cluster.Supervisor, [topologies, [name: Example.ClusterSupervisor]]},
      %{
        id: Example.ClusterConnector,
        restart: :transient,
        start:
          {Task, :start_link,
           [
             fn ->
               #  Horde.Supervisor.wait_for_quorum(Example.MySupervisor, 30_000)
               #  Horde.Supervisor.start_child(HelloWorld.HelloSupervisor, HelloWorld.SayHello)

               #  Horde.Supervisor.start_child(
               #    Example.Supervisor,
               #    Example.Worker
               #  )
               Horde.Supervisor.start_child(
                 Example.MySupervisor,
                 Example.Counter
               )

               #  Node.list()
               #  |> Enum.each(fn node ->
               #    Example.StateHandoff.join(node)
               #  end)
             end
           ]}
      }
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Example.Supervisor]

    Supervisor.start_link(children, opts)
  end

  defp registry_members do
    [
      {Example.MyRegistry, :"a@127.0.0.1"},
      {Example.MyRegistry, :"b@127.0.0.1"},
      {Example.MyRegistry, :"c@127.0.0.1"}
    ]
  end

  defp supervisor_members do
    [
      {Example.MySupervisor, :"a@127.0.0.1"},
      {Example.MySupervisor, :"b@127.0.0.1"},
      {Example.MySupervisor, :"c@127.0.0.1"}
    ]
  end
end
