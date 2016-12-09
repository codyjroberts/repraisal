defmodule RpAPI.CacheController do
  alias CommentPipeline.RepoRequester
  alias RpAPI.{Cache, Repo, Project, User}
  require Logger
  import Ecto.Query

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
      struct -> persist_and_cache(project, cache, [since: Ecto.DateTime.to_iso8601(struct.last_accessed)])
    end
  end

  defp persist_and_cache(project, cache, opts \\ []) do
    since = Keyword.get(opts, :since, "2016-12-06T23:59:59Z")

    RepoRequester.sync_notify(self(), Map.put(project, :since, since))

    receive do
      {_, []} ->
        case Repo.get_by(Project, project) do
          nil -> Poison.encode(%{error: "no comments found"})
          struct ->
            users = Repo.all(from u in User, where: u.project_id == ^struct.id)
            {:ok, resp} = Poison.encode(users)

            expiry = :os.system_time(:seconds) + ttl()
            :ets.insert(cache, {project, resp, expiry})
            resp
        end
      {_, results} ->
        %{repo: repo, owner: owner} = project

        result =
          %Project{owner: owner, repo: repo}
          |> Ecto.Changeset.change(%{last_accessed: Ecto.DateTime.utc})
          |> Repo.insert_or_update

        case result do
          {:ok, struct} ->
            struct
            for u <- results do
              Repo.insert! %{u | project_id: struct.id}
            end
          {:error, changeset} -> Logger.warn "failed to insert"
        end

        case Poison.encode(results) do
          {:ok, resp} ->
            expiry = :os.system_time(:seconds) + ttl()
            :ets.insert(cache, {project, resp, expiry})
            resp
          _ -> Logger.warn "Encoding failure"
        end
    after 10_000 ->
      "{\"error\": \"3rd party APIs are down\"}"
    end
  end

  defp expired?(result, exp, t) when t < exp, do: {:found, result}
  defp expired?(_, _, _), do: nil
  defp ttl, do: Application.get_env(:rp_api, :cache_ttl)
end
