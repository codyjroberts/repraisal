defmodule DB.Repo.Migrations.AddProjectSentiment do
  use Ecto.Migration

  def change do
    alter table(:project) do
      add :user_sentiment, :float
    end
  end
end
