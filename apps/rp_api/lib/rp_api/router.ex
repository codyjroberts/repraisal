defmodule RpAPI.Router do
  use Plug.Router
  alias CommentPipeline.{RepoRequester, Repo}
  alias RpAPI.CacheController

  if Mix.env == :dev do
    use Plug.Debugger
  end

  plug Plug.Logger
  plug :match
  plug :dispatch


  get "/repo" do
    conn = fetch_query_params(conn)
    %{ "owner" => owner, "repo" => repo } = conn.params

    {_, resp} = CacheController.query(%Repo{owner: owner, repo: repo})

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, resp)
  end

  match _ do
    send_resp(conn, 404, "")
  end
end
