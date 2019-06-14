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
    count = get_global_counter()
    # count = Example.StateHandoff.getcount()
    IO.puts("Current count is: #{count}")
    send(self(), :say_hello)

    {:ok, count}
  end

  def handle_info({:EXIT, _from, _reason}, state) do
    IO.puts("EXITING, STATE: #{IO.inspect(state)}")
    {:stop, :shutdown, state}
  end

  def terminate(_reason, count) do
    IO.puts("Triggering the terminate function! count is #{count}")
    # Example.StateHandoff.handoff(count)
    put_global_counter(count)
    :ok
  end

  def handle_info(:say_hello, counter) do
    Logger.info("HELLO from node #{inspect(Node.self())}")
    Logger.info("Current count is: #{inspect(counter)}")
    Process.send_after(self(), :say_hello, 5000)

    {:noreply, put_global_counter(counter + 1)}
    # {:noreply, counter + 1}
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

  def handle_call(:how_many?, _from, counter) do
    {:reply, counter, counter}
  end

  def via_tuple(name), do: {:via, Horde.Registry, {Example.MyRegistry, name}}
end
