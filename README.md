# Description
Repraisal is an experiement with Elixir's experimental GenStage.  It uses GenStage
to fetch comments on a particular repository, aggregate them by user, and batch process
them for sentiment analysis using Indico's mighty fine API.  The implementation is currently
a bit rough and doesn't take full advantage of GenStage's abilities.

Disclaimer: the authors of this toy project claim no significance in the results

## Requirements
Elixir v1.3

Erlang v18

Postgres >= 9.3

## Installation
```
git clone https://github.com/codyjroberts/repraisal.git
cd repraisal
mix deps.get
mix do ecto.create -r DB.Repo, ecto.migrate -r DB.Repo
```

create a .env file in the project root directory with the following contents:

```
export INDICO_API_KEY="<YOUR_API_KEY>"
export GITHUB_TOKEN="<YOUR_GITHUB_TOKEN>"
```

```
source .env
mix run --no-halt
```

## Tests
A few integration tests have skip tags to avoid hitting 3rd party APIs, feel free to comment out the skip tags.
This isn't desirable and will be fixed in the future.

```
mix test
```

## Endpoints
Single endpoint for querying repositories

### /comment_analysis/:owner/:repo

e.g.

`curl "http://localhost:8080/comment_analysis/elixir-lang/elixir"`
