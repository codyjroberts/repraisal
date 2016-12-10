defmodule RpAPI.Repo.Migrations.AddProjectToUsers do
  use Ecto.Migration

  def change do
    alter table(:user) do
      add :project_id, references(:project)
    end
  end
end
