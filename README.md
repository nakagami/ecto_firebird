# Ecto Firebird Adapter

An Ecto Firebird adapter. Uses [Firebirdex](https://github.com/nakagami/firebirdex)
as the driver to communicate with [Firebird](https://firebirdsql.org/).

Based on [Ecto SQLite3 Adapter](https://github.com/elixir-sqlite/ecto_sqlite3).
Special thanks to the developers of Ecto SQLite3 Adapter!

## Installation

```elixir
defp deps do
  [
    ...
    {:ecto_firebird, ">= 0.0.0"}
  ]
end
```

## Usage

Define your repo similar to this.

```elixir
defmodule MyApp.Repo do
  use Ecto.Repo, otp_app: :my_app, adapter: Ecto.Adapters.Firebird
end
```

Configure your repository similar to the following.

```elixir
config :my_app,
  ecto_repos: [MyApp.Repo]

config :my_app, MyApp.Repo,
  hostname: "servername",
  username: "SYSDBA",
  password: "secret",
  database: "/path/to/my/database.db"
```
