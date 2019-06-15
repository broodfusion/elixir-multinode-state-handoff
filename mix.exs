defmodule Example.MixProject do
  use Mix.Project

  def project do
    [
      app: :multi_node_example,
      version: "0.1.0",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :httpoison],
      mod: {Example.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:httpoison, "~> 1.2"},
      {:jason, "~> 1.0"},
      {:libcluster, "~> 3.0.3"},
      {:redix, ">= 0.0.0"},
      {:horde, git: "https://github.com/derekkraan/horde.git"},
      {:delta_crdt, git: "https://github.com/derekkraan/delta_crdt_ex.git", override: true}
    ]
  end
end
