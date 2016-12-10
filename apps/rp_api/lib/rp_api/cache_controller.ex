defmodule RpAPI.CacheController do
  alias CommentPipeline.RepoRequester
  alias RpAPI.{Cache, Repo, Project, User}
  require Logger

  @timeout 10_000 # 10 seconds

  def query(project, opts \\ []) do
    cache = Keyword.get(opts, :cache, Cache)
    case lookup(project, cache) do
      {:found, result} -> {:cached, result}
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
      struct ->
        last_accessed = "#{Ecto.DateTime.to_iso8601(struct.last_accessed)}Z"
        Task.async(fn -> persist_and_cache(project, cache, [since: last_accessed]) end)

        struct.id
        |> Project.users
        |> encode(project)
    end
  end

  defp persist_and_cache(project, cache, opts \\ []) do
    since = Keyword.get(opts, :since, "2016-12-06T23:59:59Z")
    RepoRequester.sync_notify(self(), Map.put(project, :since, since))

    receive do
      {_, []} ->
        case Repo.get_by(Project, project) do
          nil -> json_error("no results")
          struct ->
            struct.id
            |> Project.users
            |> encode(project, cache)
        end

      {_, results} ->
        %{repo: repo, owner: owner} = project

        result =
          case Repo.get_by(Project, project) do
            nil -> %Project{owner: owner, repo: repo}
            p -> p
          end
          |> Ecto.Changeset.change(%{last_accessed: Ecto.DateTime.utc})
          |> Repo.insert_or_update

        case result do
          {:ok, p} ->
            for old_user <- results do
              User
              |> Repo.get_by(%{login: old_user.login, project_id: p.id})
              |> User.update_average(old_user, p.id)
            end
          {:error, changeset} -> Logger.warn "failed to insert project #{IO.inspect(changeset)}"
        end

        encode(project, results, cache)
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

  defp json_error(reason), do: Poison.encode(%{error: reason}) |> elem(1)
  defp expired?(result, exp, t) when t < exp, do: {:found, result}
  defp expired?(_, _, _), do: nil
  defp ttl, do: Application.get_env(:rp_api, :cache_ttl)
end
