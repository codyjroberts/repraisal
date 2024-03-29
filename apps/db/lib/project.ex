defmodule DB.Project do
  use Ecto.Schema
  import Ecto.Query
  alias DB.{User, Repo, Project}
  @derive {Poison.Encoder, only: [:owner, :repo, :user_sentiment, :users]}

  schema "project" do
    field :owner, :string
    field :repo, :string
    field :last_accessed, Ecto.DateTime
    field :user_sentiment, :float
    has_many :users, User

    timestamps
  end

  def users(project_id) do
    User
    |> join(:left, [u], p in assoc(u, :project))
    |> where([_, p], p.id == ^project_id)
    |> select([u, _], u)
    |> Repo.all
  end

  def last_accessed(project_id) do
    project = Repo.get!(Project, project_id)
    "#{Ecto.DateTime.to_iso8601(project.last_accessed)}Z"
  end

  def insert_or_update(project = %{repo: repo, owner: owner}) do
    case Repo.get_by(Project, project) do
      nil -> %Project{owner: owner, repo: repo}
      p -> p
    end
    |> Ecto.Changeset.change(%{last_accessed: Ecto.DateTime.utc})
    |> Repo.insert_or_update
  end

  def update_sentiment(project_id) do
    query = from u in User, where: u.project_id == ^project_id
    sentiment = Repo.aggregate(query, :avg, :average_sentiment)

    Repo.get!(Project, project_id)
    |> Ecto.Changeset.change(%{user_sentiment: sentiment})
    |> Repo.insert_or_update
  end
end
