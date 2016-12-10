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
      struct ->
        Task.async(fn -> persist_and_cache(project, cache, [since: "#{Ecto.DateTime.to_iso8601(struct.last_accessed)}Z"]) end)
        users = Repo.all(from u in User, where: u.project_id == ^struct.id)
        case Poison.encode(users) do
          {:ok, resp} ->
            expiry = :os.system_time(:seconds) + ttl()
            :ets.insert(cache, {project, resp, expiry})
            resp
          _ ->
            {:ok, resp} = Poison.encode(%{error: "no comments found"})
            resp
        end
    end
  end

  defp persist_and_cache(project, cache, opts \\ []) do
    since = Keyword.get(opts, :since, "2016-12-06T23:59:59Z")
    RepoRequester.sync_notify(self(), Map.put(project, :since, since))

    receive do
      {_, []} ->
        case Repo.get_by(Project, project) do
          nil ->
            {:ok, resp} = Poison.encode(%{error: "no comments found"})
            resp
          struct ->
            users = Repo.all(from u in User, where: u.project_id == ^struct.id)
            case Poison.encode(users) do
              {:ok, resp} ->
                expiry = :os.system_time(:seconds) + ttl()
                :ets.insert(cache, {project, resp, expiry})
                resp
              _ ->
                {:ok, resp} = Poison.encode(%{error: "no comments found"})
                resp
            end
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
            for u <- results do
              case Repo.get_by(User, %{login: u.login}) do
            nil -> Repo.insert! %{u | project_id: p.id}
            struct ->
              struct
              |> Ecto.Changeset.change(%{
                   project_id: p.id,
                   comment_count: struct.comment_count + u.comment_count,
                   average_sentiment: ((struct.comment_count * struct.average_sentiment) + u.average_sentiment) / (struct.comment_count + u.comment_count)
              })
              |> Repo.update
              end
            end
          {:error, changeset} -> Logger.warn "failed to insert project"
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
