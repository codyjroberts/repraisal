use Mix.Config
config :db, DB.Repo,
  adapter: Ecto.Adapters.Postgres,
  database: "db",
  username: "postgres",
  password: "postgres",
  template: "template0",
  host: "localhost",
  port: "5432"
