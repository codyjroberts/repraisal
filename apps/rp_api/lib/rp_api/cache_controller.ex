defmodule RpAPI.CacheController do
  alias CommentPipeline.RepoRequester
  alias DB.{Repo, Project, User}
  alias RpAPI.Cache
  require Logger

  @timeout 10_000 # 10 seconds

  def query(project, opts \\ []) do
    cache = Keyword.get(opts, :cache, Cache)
    case lookup(project, cache) do
      {:found, result} ->
        Task.async(fn -> cache_results(project, cache) end)
        {:cached, result}
      _ -> {:fresh, cache_results(project, cache)}
    end
  end

  defp lookup(project, cache) do
    case :ets.lookup(cache, project) do
      [{_, result, exp}] ->
        expired?(result, exp, :os.system_time(:seconds))
      _ -> nil
    end
  end

  defp cache_results(project, cache) do
    case Repo.get_by(Project, project) do
      nil -> persist_and_cache(project, cache)
      p ->
        last_accessed = Project.last_accessed(p.id)
        Task.async(fn -> persist_and_cache(project, cache, [since: last_accessed]) end)

        p
        |> Repo.preload(:users)
        |> encode(project, cache)
    end
  end

  defp persist_and_cache(project, cache, opts \\ []) do
    since = Keyword.get(opts, :since, "2016-12-06T23:59:59Z")
    RepoRequester.sync_notify(self(), Map.put(project, :since, since))

    receive do
      {_, []} ->
        case Repo.get_by(Project, project) do
          nil -> json_error("no results")
          p ->
            Project.update_sentiment(p.id)

            p
            |> Repo.preload(:users)
            |> encode(project, cache)
        end

      {_, results} ->
        case Project.insert_or_update(project) do
          {:ok, p} ->
            for old_user <- results do
              User
              |> Repo.get_by(%{login: old_user.login, project_id: p.id})
              |> User.update_average(old_user, p.id)
            end

            Project.update_sentiment(p.id)

            p
            |> Repo.preload(:users)
            |> encode(project, cache)
          {:error, changeset} -> Logger.error inspect(changeset)
        end
    after @timeout ->
      json_error("3rd party APIs are down")
    end
  end

  defp encode(results, project, cache \\ nil) do
    case Poison.encode(results) do
      {:ok, resp} ->
        if cache, do: update_cache(project, resp, cache), else: resp
      _ ->
        Logger.warn "Encoding failure"
        json_error("no results")
    end
  end

  defp update_cache(project, response, cache) do
    expiry = :os.system_time(:seconds) + ttl()
    :ets.insert(cache, {project, response, expiry})
    response
  end


  defp expired?(result, exp, t) when t < exp, do: {:found, result}
  defp json_error(reason), do: Poison.encode(%{error: reason}) |> elem(1)
  defp expired?(_, _, _), do: nil
  defp ttl, do: Application.get_env(:rp_api, :cache_ttl)
end
