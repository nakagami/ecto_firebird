# Ecto Firebird Adapter

An Ecto Firebird adapter. Uses [Firebirdex](https://github.com/nakagami/firebirdex)
as the driver to communicate with [Firebird](https://firebirdsql.org/).

Still not working, and  I don't know if we can get it to work at this point.

## Installation

Not yet published on hex.pm

```elixir
def deps do
  [
    {:ecto_firebird, git: "https://github.com/nakagami/ecto_firebird.git", branch: "master"}
  ]
end
```

## Special Thanks

Primarily, the utility functions and test code were copied
from [Ecto SQLite3](https://github.com/elixir-sqlite/ecto_sqlite3) and heavily modified for use.

