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

  defoverridable stream: 5

  @behaviour Ecto.Adapter.Storage
  alias Ecto.Adapters.Firebird.Codec

  ## Query

  @impl true
  def prepare(:all, query) do
    sql = query |> Ecto.Adapters.Firebird.Connection.all() |> IO.iodata_to_binary()

    case limit_offset_param_indices(query) do
      {limit_idx, offset_idx} ->
        # Firebird's OFFSET/FETCH syntax requires parameters in the order
        # [offset, limit], but Ecto plans them as [limit, offset].
        # Disable caching for these queries so execute/5 can swap them.
        {:nocache, {sql, {limit_idx, offset_idx}}}

      nil ->
        {:cache, {System.unique_integer([:positive]), sql}}
    end
  end

  def prepare(operation, query) when operation in [:update_all, :delete_all] do
    super(operation, query)
  end

  @impl true
  def execute(
        adapter_meta,
        query_meta,
        {:nocache, {prepared, swap_indices}},
        params,
        opts
      ) do
    params = swap_params(params, swap_indices)

    Ecto.Adapters.SQL.execute(
      :named,
      adapter_meta,
      query_meta,
      {:nocache, {0, prepared}},
      params,
      opts
    )
  end

  def execute(adapter_meta, query_meta, prepared, params, opts) do
    Ecto.Adapters.SQL.execute(:named, adapter_meta, query_meta, prepared, params, opts)
  end

  @impl true
  def stream(
        adapter_meta,
        query_meta,
        {:nocache, {prepared, swap_indices}},
        params,
        opts
      ) do
    params = swap_params(params, swap_indices)

    Ecto.Adapters.SQL.stream(
      adapter_meta,
      query_meta,
      {:nocache, {0, prepared}},
      params,
      opts
    )
  end

  def stream(adapter_meta, query_meta, prepared, params, opts) do
    Ecto.Adapters.SQL.stream(adapter_meta, query_meta, prepared, params, opts)
  end

  defp limit_offset_param_indices(%{
         limit: %{expr: limit_expr},
         offset: %{expr: offset_expr}
       }) do
    with limit_idx when is_integer(limit_idx) <- param_index(limit_expr),
         offset_idx when is_integer(offset_idx) <- param_index(offset_expr) do
      {limit_idx, offset_idx}
    else
      _ -> nil
    end
  end

  defp limit_offset_param_indices(_query), do: nil

  defp param_index({:^, [], [idx]}), do: idx
  defp param_index(_expr), do: nil

  defp swap_params(params, {idx1, idx2}) do
    val1 = Enum.at(params, idx1)
    val2 = Enum.at(params, idx2)

    params
    |> List.replace_at(idx1, val2)
    |> List.replace_at(idx2, val1)
  end

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

  def dumpers({:map, _}, type),
    do: [&Ecto.Type.embedded_dump(type, &1, :json), &Codec.json_encode/1]

  def dumpers(:map, type), do: [type, &Codec.json_encode/1]
  def dumpers(_, type), do: [type]
end
