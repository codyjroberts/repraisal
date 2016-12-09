defmodule RpAPI.Project do
  use Ecto.Schema

  schema "project" do
    field :owner, :string
    field :repo, :string
    field :last_accessed, Ecto.DateTime

    timestamps
  end
end
