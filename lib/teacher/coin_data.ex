defmodule Teacher.CoinData do
  def fetch(id) do
    id
    |> Atom.to_string()
    |> String.upcase()
    |> url()
    |> HTTPoison.get!()
    |> Map.get(:body)
    |> Jason.decode!()
  end

  defp url(id) do
    "http://coincap.io/page/#{id}"
  end
end
