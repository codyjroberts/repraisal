defmodule CommentPipelineTest do
  use ExUnit.Case
  doctest CommentPipeline

  alias CommentPipeline.{CommentRetriever, RepoRequester}
  alias Experimental.GenStage

  @params %{owner: "elixir-lang", repo: "elixir"}

  describe "RepoRequester" do
    test "emits repo" do
      {:ok, rr} = RepoRequester.start_link()
      {:ok, f} = Forwarder.start_link({:consumer, self(), subscribe_to: [rr]})
      assert_receive {:consumer_subscribed, _}

      RepoRequester.sync_notify(self(), @params)

      response = @params
      assert_receive {:consumed, [{_, ^response}]}
    end
  end

  describe "CommentRetriever" do
    @tag :skip # Avoid unnecessary API calls
    test "fetches comments" do
      {:ok, rr} = RepoRequester.start_link()
      {:ok, cr} = CommentRetriever.start_link(self())
      {:ok, _} = Forwarder.start_link({:consumer, self(), subscribe_to: [cr]})
      assert_receive {:consumer_subscribed, _}

      RepoRequester.sync_notify(self(), @params)
      Process.sleep(5000)

      assert_receive {:consumed, [{_, [response]}]}
      for r <- response do
        assert Map.has_key?(r, "body")
      end
    end
  end
end
