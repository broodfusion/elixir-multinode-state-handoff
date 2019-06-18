defmodule Example.Counter do
  use GenServer
  require Logger

  def child_spec(opts) do
    name = Keyword.get(opts, :name, __MODULE__)

    %{
      id: "#{__MODULE__}_#{name}",
      start: {__MODULE__, :start_link, [name]},
      shutdown: 10_000,
      restart: :transient
    }
  end

  def start_link(name) do
    GenServer.start_link(__MODULE__, [], name: via_tuple(name))
  end

  def init(_args) do
    Process.flag(:trap_exit, true)
    # count = Example.StateHandoff.getcount()
    Logger.warn("getting from redis")
    count = get_count_from_redis("count")

    IO.puts("Current count is: #{count}")
    send(self(), :say_hello)

    {:ok, count}
  end

  @doc """
  iex(2)> map = %{hello: "there", user: %{name: "bob"}}
  %{hello: "there", user: %{name: "bob"}}
  iex(3)> {:ok, json} = Jason.encode(map)
  iex(7)> Redix.command(conn, ["JSON.SET", "map", ".", json])
  {:ok, "OK"}
  iex(4)> Redix.command(conn, ["JSON.GET", "map"])
  {:ok, "{\"hello\":\"there\",\"user\":{\"name\":\"bob\"}}"}
  iex(9)> Redix.command(conn, ["JSON.TYPE", "map"])
  {:ok, "object"}


  {:ok, "{\"hello\":\"there\",\"user\":{\"name\":\"bob\"}}"}
  iex(5)> Redix.command(conn, ["JSON.SET", "arr", ".", '[{"hello": true}]' ])
  {:ok, "OK"}
  iex(6)> Redix.command(conn, ["JSON.GET", "arr"])
  {:ok, "[{\"hello\":true}]"}
  iex(7)> Redix.command(conn, ["JSON.TYPE", "arr"])
  {:ok, "array"}
  iex(8)> Redix.command(conn, ["JSON.SET", "arr", ".", '{"hello": true, "user": "bob"}' ])
  {:ok, "OK"}
  iex(9)> Redix.command(conn, ["JSON.GET", "arr"])
  {:ok, "{\"hello\":true,\"user\":\"bob\"}"}
  iex(10)> Redix.command(conn, ["JSON.SET", "arr", ".", '{"hello": true, "user": {"first_name": "bob"}}' ])
  {:ok, "OK"}
  iex(11)> Redix.command(conn, ["JSON.GET", "arr"])
  {:ok, "{\"hello\":true,\"user\":{\"first_name\":\"bob\"}}"}
  iex(12)> {:ok, json} = Redix.command(conn, ["JSON.GET", "arr"])
  {:ok, "{\"hello\":true,\"user\":{\"first_name\":\"bob\"}}"}
  iex(13)> json
  "{\"hello\":true,\"user\":{\"first_name\":\"bob\"}}"
  iex(14)> Jason.encode(json)
  {:ok, "\"{\\\"hello\\\":true,\\\"user\\\":{\\\"first_name\\\":\\\"bob\\\"}}\""}
  iex(15)> Jason.decode(json)
  {:ok, %{"hello" => true, "user" => %{"first_name" => "bob"}}}
  """
  def get_count_from_redis(key) do
    case Redix.command(:redix, ["JSON.GET", key]) do
      {:ok, nil} ->
        0

      {:ok, count} ->
        Redix.command(:redix, ["JSON.DEL", key])
        String.to_integer(count)
    end
  end

  def handle_info({:EXIT, _from, _reason}, state) do
    IO.puts("EXITING, STATE: #{IO.inspect(state)}")
    {:stop, :shutdown, state}
  end

  def handle_info(:say_hello, count) do
    Logger.info("HELLO from node #{inspect(Node.self())}")
    Logger.info("Current count is: #{inspect(count)}")
    Process.send_after(self(), :say_hello, 10000)

    # {:noreply, put_global_counter(counter + 1)}
    # {:noreply, Example.StateHandoff.setcount(count + 1)}
    {:noreply, count + 1}
  end

  def terminate(_reason, count) do
    Redix.command(:redix, ["JSON.SET", "count", ".", count])
    Logger.warn("Done setting count in redis")
    # :ok = Example.StateHandoff.handoff(count)
  end

  defp get_global_counter() do
    case Horde.Registry.meta(Example.MyRegistry, "count") do
      {:ok, count} ->
        count

      :error ->
        put_global_counter(0)
        get_global_counter()
    end
  end

  defp put_global_counter(counter_value) do
    :ok = Horde.Registry.put_meta(Example.MyRegistry, "count", counter_value)
    counter_value
  end

  def via_tuple(name), do: {:via, Horde.Registry, {Example.MyRegistry, name}}
end
