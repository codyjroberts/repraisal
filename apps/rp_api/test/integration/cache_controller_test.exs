defmodule RpAPI.CacheControllerTest do
  use ExUnit.Case, async: true
  alias CommentPipeline.{RepoRequester, CommentRetriever, CommentAnalyzer}
  alias RpAPI.CacheController

  setup do
    RepoRequester.start_link()
    CommentRetriever.start_link()
    CommentAnalyzer.start_link()

    table = :ets.new(:testcache, [:set, :public, :named_table])
    repo = %{owner: "elixir-lang", repo: "elixir"}

    [table: table, repo: repo]
  end

  @tag :skip # Avoid unnecessary API calls
  test "cache expires", %{table: table, repo: repo} do
    assert {:fresh, _} = CacheController.query(repo, [cache: table])
    assert {:cached, _} = CacheController.query(repo, [cache: table])

    # Wait for expiration
    Process.sleep(1500)
    assert {:fresh, _} = CacheController.query(repo, [cache: table])
  end
end
