defmodule CommentPipeline.CommentRetriever do
  @moduledoc """
  Fetches Repo's comments from Github
  """

  alias CommentPipeline.Repo
  alias Experimental.GenStage
  use GenStage

  def start_link(recipient \\ []) do
    GenStage.start_link(__MODULE__, recipient, name: __MODULE__)
  end

  def init(recipient) do
    {:producer_consumer, recipient, subscribe_to: [CommentPipeline.RepoRequester]}
  end

  # Called everytime CommentAnalyzer asks for data
  def handle_events(events, _from, state) do
    [{from, events}] = events
    events = Enum.map([events], &fetch_comments(&1))
    {:noreply, [{from, events}], state}
  end

  defp fetch_comments(%Repo{owner: owner, repo: repo}) do
    client = Tentacat.Client.new(%{access_token: System.get_env("GITHUB_TOKEN")})
    Tentacat.Issues.Comments.filter_all(owner, repo, [since: "2016-12-06T23:59:59Z"], client)
  end
end
