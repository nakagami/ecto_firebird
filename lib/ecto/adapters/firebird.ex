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

  @impl true
  def loaders({:map, _}, type), do: [&Codec.json_decode/1, type]
  def loaders(:map, type), do: [&Codec.json_decode/1, type]
  def loaders(:float, type), do: [&Codec.float_decode/1, type]
  def loaders(:boolean, type), do: [&Codec.bool_decode/1, type]
  def loaders(:binary_id, type), do: [Ecto.UUID, type]
  def loaders({:array, _}, type), do: [&Codec.json_decode/1, type]
  def loaders(_, type), do: [type]

  ##
  ## Dumpers
  ##

  @impl true
  def dumpers(:binary, type), do: [type, &Codec.blob_encode/1]
  def dumpers(:binary_id, type), do: [type, &Codec.uuid_encode/1]
  def dumpers(:uuid, type), do: [type, &Codec.uuid_encode/1]
  def dumpers({:array, _}, type), do: [type, &Codec.json_encode/1]
  def dumpers({:map, _}, type), do: [&Ecto.Type.embedded_dump(type, &1, :json), &Codec.json_encode/1]
  def dumpers(:map, type), do: [type, &Codec.json_encode/1]
  def dumpers(_, type), do: [type]

end
