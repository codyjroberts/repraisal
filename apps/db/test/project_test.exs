defmodule DB.ProjectTest do
  use ExUnit.Case
  alias DB.{Repo, Project, User}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(DB.Repo)
  end

  describe "last_accessed/1" do
    test "should return correct timestamp" do
      time = Ecto.DateTime.utc
      case Repo.insert(%Project{last_accessed: time}) do
        {:ok, p} ->
          assert Project.last_accessed(p.id) == "#{Ecto.DateTime.to_iso8601(time)}Z"
        _ -> assert false
      end
    end
  end

  describe "update_sentiment/1" do
    test "accurately update sentiment" do
      p = Repo.insert!(%Project{owner: "test", repo: "test"})
      u1 = Repo.insert!(%User{project_id: p.id, average_sentiment: 0.50, comment_count: 1})
      u2 = Repo.insert!(%User{project_id: p.id, average_sentiment: 0.70, comment_count: 1})

      case Project.update_sentiment(p.id) do
        {:ok, new_p} ->
          assert new_p.user_sentiment == 0.60
        _ -> assert false
      end
    end
  end

  test "insert_or_update/1" do
    {:ok, p} = Project.insert_or_update(%{owner: "bruce", repo: "willis"})
    la = p.last_accessed
    Process.sleep(1000)
    assert Ecto.DateTime.compare(la, Ecto.DateTime.utc) == :lt

    Process.sleep(1000)
    {:ok, p} = Project.insert_or_update(%{owner: "bruce", repo: "willis"})
    assert Ecto.DateTime.compare(p.last_accessed, la) == :gt
  end
end
