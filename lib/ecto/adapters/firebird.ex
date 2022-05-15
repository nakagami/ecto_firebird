defmodule Ecto.Adapters.Firebird do
  @moduledoc """
  Adapter module for Firebird.

  It uses `Firebirdex` for communicating to the database.

  ## Options

  Firebird options split in different categories described
  below. All options can be given via the repository
  configuration:

  ### Connection options

    * `:protocol` - Set to `:socket` for using UNIX domain socket, or `:tcp` for TCP
      (default: `:socket`)
    * `:hostname` - Server hostname
    * `:port` - Server port (default: 3305)
    * `:username` - Username
    * `:password` - User password
    * `:database` - the database to connect to
    * `:pool` - The connection pool module, defaults to `DBConnection.ConnectionPool`
    * `:show_sensitive_data_on_connection_error` - show connection data and
      configuration whenever there is an error attempting to connect to the
      database

  We also recommend developers to consult the `Firebirdex.start_link/1` documentation
  for a complete listing of all supported options.

  ## Limitations

  There are some limitations when using Ecto with Firebird that one
  needs to be aware of.

  ### UUIDs

  Firebird does not support UUID types. Ecto emulates them by using
  `binary(16)`.

  ### Read after writes

  Because Firebird does not support RETURNING clauses in INSERT and
  UPDATE, it does not support the `:read_after_writes` option of
  `Ecto.Schema.field/3`.

  ### DDL Transaction

  Firebird does not support migrations inside transactions as it
  automatically commits after some commands like CREATE TABLE.
  Therefore Firebird migrations does not run inside transactions.

  ### JSON support

  Even though the adapter will convert `:map` fields into JSON back and forth,
  actual value is stored in Text column.

  ### usec in datetime

  Old Firebird versions did not support usec in datetime while
  more recent versions would round or truncate the usec value.

  Therefore, in case the user decides to use microseconds in
  datetimes and timestamps with Firebird, be aware of such
  differences and consult the documentation for your Firebird
  version.

  If your version of Firebird supports microsecond precision, you
  will be able to utilize Ecto's usec types.
  """

  # Inherit all behaviour from Ecto.Adapters.SQL
  use Ecto.Adapters.SQL, driver: :myxql

  # And provide a custom storage implementation
  @behaviour Ecto.Adapter.Storage
  @behaviour Ecto.Adapter.Structure

  ## Custom Firebird types

  @impl true
  def loaders({:map, _}, type),   do: [&json_decode/1, &Ecto.Type.embedded_load(type, &1, :json)]
  def loaders(:map, type),        do: [&json_decode/1, type]
  def loaders(:float, type),      do: [&float_decode/1, type]
  def loaders(:boolean, type),    do: [&bool_decode/1, type]
  def loaders(:binary_id, type),  do: [Ecto.UUID, type]
  def loaders(_, type),           do: [type]

  defp bool_decode(<<0>>), do: {:ok, false}
  defp bool_decode(<<1>>), do: {:ok, true}
  defp bool_decode(<<0::size(1)>>), do: {:ok, false}
  defp bool_decode(<<1::size(1)>>), do: {:ok, true}
  defp bool_decode(0), do: {:ok, false}
  defp bool_decode(1), do: {:ok, true}
  defp bool_decode(x), do: {:ok, x}

  defp float_decode(%Decimal{} = decimal), do: {:ok, Decimal.to_float(decimal)}
  defp float_decode(x), do: {:ok, x}

  defp json_decode(x) when is_binary(x), do: {:ok, MyXQL.json_library().decode!(x)}
  defp json_decode(x), do: {:ok, x}

  ## Storage API

  @impl true
  def storage_up(opts) do
    database = Keyword.fetch!(opts, :database) || raise ":database is nil in repository configuration"
    opts = Keyword.delete(opts, :database)
    charset = opts[:charset] || "utf8mb4"

    command =
      ~s(CREATE DATABASE "#{database}" DEFAULT CHARACTER SET = #{charset})
      |> concat_if(opts[:collation], &"DEFAULT COLLATE = #{&1}")

    case run_query(command, opts) do
      {:ok, _} ->
        :ok
      {:error, %{mysql: %{name: :ER_DB_CREATE_EXISTS}}} ->
        {:error, :already_up}
      {:error, error} ->
        {:error, Exception.message(error)}
      {:exit, exit} ->
        {:error, exit_to_exception(exit)}
    end
  end

  defp concat_if(content, nil, _fun),  do: content
  defp concat_if(content, value, fun), do: content <> " " <> fun.(value)

  @impl true
  def storage_down(opts) do
    database = Keyword.fetch!(opts, :database) || raise ":database is nil in repository configuration"
    opts = Keyword.delete(opts, :database)
    command = ~s{DROP DATABASE "#{database}"}

    case run_query(command, opts) do
      {:ok, _} ->
        :ok
      {:error, %{mysql: %{name: :ER_DB_DROP_EXISTS}}} ->
        {:error, :already_down}
      {:error, %{mysql: %{name: :ER_BAD_DB_ERROR}}} ->
        {:error, :already_down}
      {:exit, :killed} ->
        {:error, :already_down}
      {:exit, exit} ->
        {:error, exit_to_exception(exit)}
    end
  end

  @impl Ecto.Adapter.Storage
  def storage_status(opts) do
    database = Keyword.fetch!(opts, :database) || raise ":database is nil in repository configuration"
    opts = Keyword.delete(opts, :database)

    check_database_query = "SELECT schema_name FROM information_schema.schemata WHERE schema_name = '#{database}'"

    case run_query(check_database_query, opts) do
      {:ok, %{num_rows: 0}} -> :down
      {:ok, %{num_rows: _num_rows}} -> :up
      other -> {:error, other}
    end
  end

  @impl true
  def supports_ddl_transaction? do
    true
  end

  @impl true
  def lock_for_migrations(meta, opts, fun) do
    %{opts: adapter_opts, repo: repo} = meta

    if Keyword.get(adapter_opts, :migration_lock, true) do
      if Keyword.fetch(adapter_opts, :pool_size) == {:ok, 1} do
        Ecto.Adapters.SQL.raise_migration_pool_size_error()
      end

      opts = opts ++ [log: false, timeout: :infinity]

      {:ok, result} =
        transaction(meta, opts, fn ->
          lock_name = "\"ecto_#{inspect(repo)}\""

          try do
            {:ok, _} = Ecto.Adapters.SQL.query(meta, "SELECT GET_LOCK(#{lock_name}, -1)", [], opts)
            fun.()
          after
            {:ok, _} = Ecto.Adapters.SQL.query(meta, "SELECT RELEASE_LOCK(#{lock_name})", [], opts)
          end
        end)

      result
    else
      fun.()
    end
  end

  @impl true
  def insert(adapter_meta, schema_meta, params, on_conflict, returning, opts) do
    %{source: source, prefix: prefix} = schema_meta
    {_, query_params, _} = on_conflict

    key = primary_key!(schema_meta, returning)
    {fields, values} = :lists.unzip(params)
    sql = @conn.insert(prefix, source, fields, [fields], on_conflict, [])
    opts = [{:cache_statement, "ecto_insert_#{source}"} | opts]

    case Ecto.Adapters.SQL.query(adapter_meta, sql, values ++ query_params, opts) do
      {:ok, %{num_rows: 1, last_insert_id: last_insert_id}} ->
        {:ok, last_insert_id(key, last_insert_id)}

      {:ok, %{num_rows: 2, last_insert_id: last_insert_id}} ->
        {:ok, last_insert_id(key, last_insert_id)}

      {:error, err} ->
        case @conn.to_constraints(err, source: source) do
          []          -> raise err
          constraints -> {:invalid, constraints}
        end
    end
  end

  defp primary_key!(%{autogenerate_id: {_, key, _type}}, [key]), do: key
  defp primary_key!(_, []), do: nil
  defp primary_key!(%{schema: schema}, returning) do
    raise ArgumentError, "Firebird does not support :read_after_writes in schemas for non-primary keys. " <>
                         "The following fields in #{inspect schema} are tagged as such: #{inspect returning}"
  end

  defp last_insert_id(nil, _last_insert_id), do: []
  defp last_insert_id(_key, 0), do: []
  defp last_insert_id(key, last_insert_id), do: [{key, last_insert_id}]

  defp append_versions(_table, [], contents) do
    {:ok, contents}
  end
  defp append_versions(table, versions, contents) do
    {:ok,
      contents <>
      Enum.map_join(versions, &~s[INSERT INTO "#{table}" (version) VALUES (#{&1});\n])}
  end

  ## Helpers

  defp run_query(sql, opts) do
    {:ok, _} = Application.ensure_all_started(:ecto_sql)
    {:ok, _} = Application.ensure_all_started(:myxql)

    opts =
      opts
      |> Keyword.drop([:name, :log, :pool, :pool_size])
      |> Keyword.put(:backoff_type, :stop)
      |> Keyword.put(:max_restarts, 0)

    task = Task.Supervisor.async_nolink(Ecto.Adapters.SQL.StorageSupervisor, fn ->
      {:ok, conn} = Firebirdex.start_link(opts)

      value = Firebirdex.query(conn, sql, [], opts)
      GenServer.stop(conn)
      value
    end)

    timeout = Keyword.get(opts, :timeout, 15_000)

    case Task.yield(task, timeout) || Task.shutdown(task) do
      {:ok, {:ok, result}} ->
        {:ok, result}
      {:ok, {:error, error}} ->
        {:error, error}
      {:exit, exit} ->
        {:exit, exit}
      nil ->
        {:error, RuntimeError.exception("command timed out")}
    end
  end

  defp exit_to_exception({%{__struct__: struct} = error, _})
       when struct in [Firebirdex.Error, DBConnection.Error],
       do: error

  defp exit_to_exception(reason), do: RuntimeError.exception(Exception.format_exit(reason))

end
