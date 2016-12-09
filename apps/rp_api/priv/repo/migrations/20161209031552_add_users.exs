defmodule RpAPI.Repo.Migrations.AddUsers do
  use Ecto.Migration

  def change do
    create table(:user) do
      add :login, :string
      add :average_sentiment, :float
      add :comment_count, :integer

      timestamps
    end
  end
end
