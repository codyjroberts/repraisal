defmodule RpAPI.Router do
  use Plug.Router
  alias CommentPipeline.RepoRequester
  alias RpAPI.CacheController

  if Mix.env == :dev do
    use Plug.Debugger
  end

  plug Plug.Logger
  plug :match
  plug :dispatch


  get "/comment_analysis/:owner/:repo" do
    conn = fetch_query_params(conn)

    {_, resp} = CacheController.query(%{owner: owner, repo: repo},
                                      Enum.to_list(conn.params))

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, resp)
  end

  match _ do
    send_resp(conn, 404, "")
  end
end
