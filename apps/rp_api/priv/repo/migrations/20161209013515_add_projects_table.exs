defmodule RpAPI.Repo.Migrations.AddProjectsTable do
  use Ecto.Migration

  def change do
    create table(:project) do
      add :owner, :string
      add :repo, :string
      add :last_accessed, :datetime

      timestamps
    end
  end
end
