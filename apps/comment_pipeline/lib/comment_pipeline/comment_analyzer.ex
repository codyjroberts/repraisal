defmodule CommentPipeline.CommentAnalyzer do
  @moduledoc """
  Analyze comments via indico.io
  """
  alias Experimental.GenStage
  alias RpAPI.User
  use GenStage

  def start_link() do
    GenStage.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    {:consumer, :ok, subscribe_to: [CommentPipeline.CommentRetriever]}
  end

  def handle_events([{from, [[]]}], _from, state) do
    GenStage.reply(from, [])
    {:noreply, [], state}
  end
  def handle_events(events, _from, state) do
    [{from, events}] = events
    for event <- events do
      comments = Enum.map(event, fn(x) ->
        {Map.get(x, "body"), get_in(x, ["user", "login"])}
      end)

      header = %{"X-ApiKey" => System.get_env("INDICO_API_KEY")}
      url = "https://apiv2.indico.io/sentiment/batch"

      without_owner = Enum.map(comments, fn({c, u}) -> c end)
      {:ok, data} = Poison.encode(%{data: without_owner})

      case HTTPoison.post(url, data, header, hackney: [:insecure]) do
        {:ok, %HTTPoison.Response{body: body}} ->
          {:ok, body} = Poison.decode(body)

          GenStage.reply(from, merge_results(comments, body))
        {:error, _} -> IO.inspect {self(), "ERROR: bad response"}
      end
    end

    {:noreply, [], state}
  end

  defp merge_results(comments, body) do
      body
      |> Map.get("results")
      |> Enum.zip(comments)
      |> Enum.map_reduce(%{}, fn({r, {c, u}}, acc) ->
        result = %{u => [r]}
        merged = Map.merge(acc, result, fn(k, v1, v2) -> v1 ++ v2 end)
        {result, merged}
      end)
      |> elem(1)
      |> Enum.into([], fn({k, v}) ->
        length = Enum.count(v)
        avg_sentiment =
          Enum.reduce(v, 0, fn(x, acc) -> x + acc end) / length
          |> Float.round(3)

        %User{
          login: k,
          average_sentiment: avg_sentiment,
          comment_count: length
        }
      end)
  end
end
