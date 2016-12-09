defmodule RpAPI.Project do
  use Ecto.Schema

  schema "project" do
    field :owner, :string
    field :repo, :string
    field :last_accessed, Ecto.DateTime
    has_many :user, RpAPI.User

    timestamps
  end
end
