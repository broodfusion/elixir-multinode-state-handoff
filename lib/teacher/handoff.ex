defmodule Example.StateHandoff do
  use GenServer
  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def child_spec(opts \\ []) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      shutdown: 10_000,
      restart: :permanent
    }
  end

  # join this crdt with one on another node by adding it as a neighbour
  def join(other_node) do
    # the second element of the tuple, { __MODULE__, node } is a syntax that
    #  identifies the process named __MODULE__ running on the other node other_node
    Logger.warn("Joining StateHandoff at #{inspect(other_node)}")
    GenServer.call(__MODULE__, {:set_neighbors, {__MODULE__, other_node}})
  end

  # store the type of bitcoin and price in the handoff crdt
  def handoff(count) do
    GenServer.call(__MODULE__, {:handoff, count})
  end

  def handoff(type, price) do
    GenServer.call(__MODULE__, {:handoff, type, price})
  end

  # pickup the stored order data for a coin type
  def pickup(coin_type) do
    GenServer.call(__MODULE__, {:pickup, coin_type})
  end

  def getcount() do
    GenServer.call(__MODULE__, {:get_count})
  end

  def setcount(count) do
    GenServer.call(__MODULE__, {:set_count, count})
  end

  def init(_) do
    # custom config for aggressive CRDT sync
    {:ok, crdt_pid} =
      DeltaCrdt.start_link(DeltaCrdt.AWLWWMap,
        notify: {self(), :members_updated},
        sync_interval: 5,
        ship_interval: 5,
        ship_debounce: 1
      )

    {:ok, crdt_pid}
  end

  # other_node is actuall a tuple { __MODULE__, other_node } passed from above,
  #  by using that in GenServer.call we are sending a message to the process
  #  named __MODULE__ on other_node
  def handle_call({:set_neighbors, other_node}, _from, this_crdt_pid) do
    Logger.warn("Sending :set_neighbors to #{inspect(other_node)} with #{inspect(this_crdt_pid)}")

    # pass our crdt pid in a message so that the crdt on other_node can add it as a neighbour
    # expect other_node to send back it's crdt_pid in response
    other_crdt_pid = GenServer.call(other_node, {:fulfill_set_neighbors, this_crdt_pid})
    # add other_node's crdt_pid as a neighbour, we need to add both ways so changes in either
    # are reflected across, otherwise it would be one way only
    DeltaCrdt.set_neighbours(this_crdt_pid, [other_crdt_pid])
    {:reply, :ok, this_crdt_pid}
  end

  # the above GenServer.call ends up hitting this callback, but importantly this
  #  callback will run in the other node that was originally being connected to
  def handle_call({:fulfill_set_neighbors, other_crdt_pid}, _from, this_crdt_pid) do
    Logger.warn("Adding neighbour #{inspect(other_crdt_pid)} to this #{inspect(this_crdt_pid)}")
    # add the crdt's as a neighbour, pass back our crdt to the original adding node via a reply
    DeltaCrdt.set_neighbours(this_crdt_pid, [other_crdt_pid])

    {:reply, this_crdt_pid, this_crdt_pid}
  end

  def handle_call({:handoff, count}, _from, crdt_pid) do
    Logger.warn("Handoff function triggering...")
    DeltaCrdt.mutate(crdt_pid, :add, [:count, count])
    Logger.warn("Added count: '#{inspect(count)} to crdt")
    Logger.warn("CRDT: #{inspect(DeltaCrdt.read(crdt_pid))}")
    {:reply, :ok_dude, crdt_pid}
  end

  def handle_call({:set_count, count}, _from, crdt_pid) do
    DeltaCrdt.mutate(crdt_pid, :add, [:count, count])
    Logger.warn("Added count: '#{inspect(count)} to crdt")
    Logger.warn("CRDT: #{inspect(DeltaCrdt.read(crdt_pid))}")
    {:reply, count, crdt_pid}
  end

  # def handle_call({:handoff, coin_type, price}, _from, crdt_pid) do
  #   DeltaCrdt.mutate(crdt_pid, :add, [coin_type, price])
  #   Logger.warn("Added #{coin_type}'s order '#{inspect(price)} to crdt")
  #   Logger.warn("CRDT: #{inspect(DeltaCrdt.read(crdt_pid))}")
  #   {:reply, :ok, crdt_pid}
  # end

  # def handle_call({:pickup, coin_type}, _from, crdt_pid) do
  #   price =
  #     crdt_pid
  #     |> DeltaCrdt.read()
  #     |> Map.get(coin_type, [])

  #   Logger.warn("CRDT: #{inspect(DeltaCrdt.read(crdt_pid))}")
  #   Logger.warn("Picked up #{inspect(price, charlists: :as_lists)} for #{coin_type}")
  #   # remove when picked up, this is a temporary storage and not meant to be used
  #   #  in any implementation beyond restarting of cross Pod processes
  #   # DeltaCrdt.mutate(crdt_pid, :remove, [coin_type])

  #   {:reply, price, crdt_pid}
  # end

  def handle_call({:get_count}, _from, crdt_pid) do
    # count =
    #   case Horde.Registry.meta(Example.MyRegistry, "count") do
    #     {:ok, count} ->
    #       count

    #     :error ->
    #       put_global_counter(0)
    #       0
    #       # get_global_counter()
    #   end

    count =
      case crdt_pid |> DeltaCrdt.read() |> Map.get(:count) do
        nil -> 0
        count -> count
      end

    Logger.warn("CURRENT CRDT STATE: #{inspect(DeltaCrdt.read(crdt_pid))}")
    Logger.warn("Got count: #{count}")
    # remove when picked up, this is a temporary storage and not meant to be used
    #  in any implementation beyond restarting of cross Pod processes
    DeltaCrdt.mutate(crdt_pid, :remove, [:count])
    {:reply, count, crdt_pid}
  end

  # defp get_global_counter() do
  #   case Horde.Registry.meta(Example.MyRegistry, "count") do
  #     {:ok, count} ->
  #       count

  #     :error ->
  #       put_global_counter(0)
  #       get_global_counter()
  #   end
  # end

  defp put_global_counter(counter_value) do
    :ok = Horde.Registry.put_meta(Example.MyRegistry, "count", counter_value)
    counter_value
  end
end
