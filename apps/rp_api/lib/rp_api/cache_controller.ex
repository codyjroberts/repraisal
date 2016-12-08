defmodule RpAPI.CacheController do
  alias CommentPipeline.RepoRequester
  alias RpAPI.Cache

  def query(name, opts \\ []) do
    cache = Keyword.get(opts, :cache, Cache)
    case lookup(name, cache) do
      {:found, result} -> {:cached, result}
      _ -> {:fresh, cache_results(name, cache)}
    end
  end

  defp lookup(name, cache) do
    case :ets.lookup(cache, name) do
      [{_, result, exp}] ->
        expired?(result, exp, :os.system_time(:seconds))
      _ -> nil
    end
  end

  defp cache_results(name, cache) do
    RepoRequester.sync_notify(self(), name)

    receive do
      {_, results} ->
        expiry = :os.system_time(:seconds) + ttl()
        :ets.insert(cache, {name, results, expiry})
        results
    after 10_000 ->
      "{\"error\": \"3rd party APIs are down\"}"
    end
  end

  defp expired?(result, exp, t) when t < exp, do: {:found, result}
  defp expired?(_, _, _), do: nil
  defp ttl, do: Application.get_env(:rp_api, :cache_ttl)
end
