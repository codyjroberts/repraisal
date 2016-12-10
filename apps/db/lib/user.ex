defmodule DB.User do
  use Ecto.Schema
  alias DB.{Repo, Project}
  @derive {Poison.Encoder, only: [:login, :average_sentiment]}

  schema "user" do
    field :login, :string
    field :average_sentiment, :float
    field :comment_count, :integer
    belongs_to :project, Project

    timestamps
  end

  def update_average(nil, user, project_id) do
    Repo.insert! %{user | project_id: project_id}
  end
  def update_average(query, user, project_id) do
    changes = %{
      project_id: project_id,
      comment_count: query.comment_count + user.comment_count,
      average_sentiment: recalculate_sentiment(query.comment_count,
                                               user.comment_count,
                                               query.average_sentiment,
                                               user.average_sentiment)
    }

    query
    |> Ecto.Changeset.change(changes)
    |> Repo.update
  end

  defp recalculate_sentiment(oldc, newc, oldsent, newsent) do
    ((oldc * oldsent) + newsent) / (oldc + newc)
  end
end
