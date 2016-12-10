defmodule RpAPI.Project do
  use Ecto.Schema
  import Ecto.Query
  alias RpAPI.{User, Repo}

  schema "project" do
    field :owner, :string
    field :repo, :string
    field :last_accessed, Ecto.DateTime
    has_many :user, RpAPI.User

    timestamps
  end

  def users(project_id) do
    User
    |> join(:left, [u], p in assoc(u, :project))
    |> where([_, p], p.id == ^project_id)
    |> select([u, _], u)
    |> Repo.all
  end
end
