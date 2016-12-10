defmodule RepraisalUmbrella.Mixfile do
  use Mix.Project

  def project do
    [apps_path: "apps",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     aliases: aliases(),
     deps: deps]
  end

  defp aliases do
    ["test": ["ecto.create --quiet -r DB.Repo", "ecto.migrate --quiet -r DB.Repo", "test"]]
  end

  defp deps do
    [
      {:mix_test_watch, "~> 0.2", only: [:dev, :test]}
    ]
  end
end
