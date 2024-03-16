defmodule Ecto.Adapters.Firebird do
  @moduledoc """
  Adapter module for Firebird.

  It uses `Firebirdex` for communicating to the database.

  ## Options

  ### Connection options

    * `:hostname` - Server hostname
    * `:port` - Server port (default: 3305)
    * `:username` - Username
    * `:password` - User password (or use FIREBIRD_PASSWORD environment)
    * `:database` - the database to connect to
    * `:pool` - The connection pool module, defaults to `DBConnection.ConnectionPool`

  We also recommend developers to consult the `Firebirdex.start_link/1` documentation.
  """

  use Ecto.Adapters.SQL, driver: :firebirdex

  @behaviour Ecto.Adapter.Storage
  alias Ecto.Adapters.Firebird.Codec

  ## Storage API

  @impl Ecto.Adapter.Storage
  def storage_down(_opts) do
    # TODO:
    :ok
  end

  @impl Ecto.Adapter.Storage
  def storage_status(options) do
    db_path = Keyword.fetch!(options, :database)

    if File.exists?(db_path) do
      :up
    else
      :down
    end
  end

  @impl true
  def storage_up(opts) do
    Keyword.fetch!(opts, :database) ||
      raise ":database is nil in repository configuration"

    opts =
      opts
      |> Keyword.put(:createdb, true)

    {:ok, state} = Firebirdex.Connection.connect(opts)
    :ok = Firebirdex.Connection.disconnect(:normal, state)
  end

  @impl Ecto.Adapter.Migration
  def supports_ddl_transaction? do
    true
  end

  @impl Ecto.Adapter.Migration
  def lock_for_migrations(_meta, _opts, fun) do
    fun.()
  end

  @impl Ecto.Adapter.Schema
  def autogenerate(:id), do: nil

  def autogenerate(:embed_id) do
    Ecto.UUID.generate()
  end

  def autogenerate(:binary_id) do
    Ecto.UUID.generate()
  end

  ##
  ## Loaders
  ##

  #  @default_datetime_type :iso8601

  @impl true
  def loaders({:map, _}, type), do: [&Codec.json_decode/1, type]
  def loaders(:map, type), do: [&Codec.json_decode/1, type]
  def loaders(:float, type), do: [&Codec.float_decode/1, type]
  def loaders(:boolean, type), do: [&Codec.bool_decode/1, type]
  def loaders(:binary_id, type), do: [Ecto.UUID, type]
  def loaders({:array, _}, type), do: [&Codec.json_decode/1, type]
  def loaders(_, type), do: [type]

  #  @impl Ecto.Adapter
  #  def loaders(:naive_datetime_usec, type) do
  #    [&Codec.naive_datetime_decode/1, type]
  #  end
  #
  #  @impl Ecto.Adapter
  #  def loaders(:time, type) do
  #    [&Codec.time_decode/1, type]
  #  end
  #
  #  @impl Ecto.Adapter
  #  def loaders(:utc_datetime_usec, type) do
  #    [&Codec.utc_datetime_decode/1, type]
  #  end
  #
  #  @impl Ecto.Adapter
  #  def loaders(:utc_datetime, type) do
  #    [&Codec.utc_datetime_decode/1, type]
  #  end
  #
  #  @impl Ecto.Adapter
  #  def loaders(:naive_datetime, type) do
  #    [&Codec.naive_datetime_decode/1, type]
  #  end
  #
  #  @impl Ecto.Adapter
  #  def loaders(:date, type) do
  #    [&Codec.date_decode/1, type]
  #  end
  #

  # when we have an e.g., max(created_date) function
  # Ecto does not truly know the return type, hence :maybe
  # see Ecto.Query.Planner.collect_fields
  #  @impl Ecto.Adapter
  #  def loaders({:maybe, :naive_datetime}, type) do
  #    [&Codec.naive_datetime_decode/1, type]
  #  end

  ##
  ## Dumpers
  ##

  @impl Ecto.Adapter
  def dumpers(:binary, type) do
    [type, &Codec.blob_encode/1]
  end

  @impl Ecto.Adapter
  def dumpers(:boolean, type) do
    [type, &Codec.bool_encode/1]
  end

  @impl Ecto.Adapter
  def dumpers(:decimal, type) do
    [type, &Codec.decimal_encode/1]
  end

  @impl Ecto.Adapter
  def dumpers(:binary_id, type) do
    [type, &Codec.uuid_encode/1]
  end

  @impl Ecto.Adapter
  def dumpers(:uuid, type) do
    [type, &Codec.uuid_encode/1]
  end

  #  @impl Ecto.Adapter
  #  def dumpers(:time, type) do
  #    [type, &Codec.time_encode/1]
  #  end
  #
  #  @impl Ecto.Adapter
  #  def dumpers(:utc_datetime, type) do
  #    dt_type = Application.get_env(:ecto_sqlite3, :datetime_type, @default_datetime_type)
  #    [type, &Codec.utc_datetime_encode(&1, dt_type)]
  #  end
  #
  #  @impl Ecto.Adapter
  #  def dumpers(:utc_datetime_usec, type) do
  #    dt_type = Application.get_env(:ecto_sqlite3, :datetime_type, @default_datetime_type)
  #    [type, &Codec.utc_datetime_encode(&1, dt_type)]
  #  end
  #
  #  @impl Ecto.Adapter
  #  def dumpers(:naive_datetime, type) do
  #    dt_type = Application.get_env(:ecto_sqlite3, :datetime_type, @default_datetime_type)
  #    [type, &Codec.naive_datetime_encode(&1, dt_type)]
  #  end
  #
  #  @impl Ecto.Adapter
  #  def dumpers(:naive_datetime_usec, type) do
  #    dt_type = Application.get_env(:ecto_sqlite3, :datetime_type, @default_datetime_type)
  #    [type, &Codec.naive_datetime_encode(&1, dt_type)]
  #  end

  @impl Ecto.Adapter
  def dumpers({:array, _}, type) do
    [type, &Codec.json_encode/1]
  end

  @impl Ecto.Adapter
  def dumpers({:map, _}, type) do
    [&Ecto.Type.embedded_dump(type, &1, :json), &Codec.json_encode/1]
  end

  @impl Ecto.Adapter
  def dumpers(:map, type) do
    [type, &Codec.json_encode/1]
  end

  @impl Ecto.Adapter
  def dumpers(_, type) do
    [type]
  end
end
