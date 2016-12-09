defmodule RpAPI.User do
  use Ecto.Schema

  schema "user" do
    field :login, :string
    field :average_sentiment, :float
    field :comment_count, :integer
    belongs_to :project, RpAPI.Project

    timestamps
  end
end

defimpl Poison.Encoder, for: RpAPI.User do
  def encode(model, opts) do
    model
      |> Map.take([:login, :average_sentiment, :comment_count])
      |> Poison.Encoder.encode(opts)
  end
end
