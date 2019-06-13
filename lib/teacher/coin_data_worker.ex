defmodule Teacher.CoinDataWorker do
  use GenServer

  alias Teacher.CoinData

  def start_link(args) do
    id = Map.get(args, :id)
    GenServer.start_link(__MODULE__, args, name: id)
  end

  def init(state) do
    Process.flag(:trap_exit, true)

    schedule_coin_fetch()
    {:ok, state}
  end

  def terminate(_reason, %{id: type, price: price}) do
    IO.puts("Triggering the terminate function!")
    Teacher.StateHandoff.handoff(type, price)
    :ok
  end

  def handle_info(:coin_fetch, state) do
    updated_state =
      state
      |> Map.get(:id)
      |> CoinData.fetch()
      |> update_state(state)

    # put_global_state(updated_state)

    if updated_state[:price] != state[:price] do
      IO.inspect("Current #{updated_state[:name]} price is $#{updated_state[:price]}")
    end

    schedule_coin_fetch()

    # {:noreply, put_in(state.btc, price)}
    {:noreply, updated_state}
  end

  # defp put_global_state(state) do
  #   :ok = Horde.Registry.put_meta(Teacher.CoinDataRegistry, "state", state)
  #   state
  # end

  # defp get_global_counter() do
  #   case Horde.Registry.meta(HelloWorld.HelloRegistry, "state") do
  #     {:ok, state} ->
  #       state

  #     :error ->
  #       put_global_state(0)
  #       get_global_state()
  #   end
  # end

  defp update_state(%{"display_name" => name, "price_usd" => price}, existing_state) do
    Map.merge(existing_state, %{name: name, price: price})
  end

  defp schedule_coin_fetch do
    Process.send_after(self(), :coin_fetch, 5_000)
  end
end
