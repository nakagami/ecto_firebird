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

  We also recommend developers to consult the `Firebirdex.start_link/1` documentation
  for a complete listing of all supported options.

  ## Limitations

  There are some limitations when using Ecto with Firebird that one
  needs to be aware of.

  ### UUIDs

  Firebird does not support UUID types. Ecto emulates them by using
  `binary(16)`.

  ### JSON support

  Even though the adapter will convert `:map` fields into JSON back and forth,
  actual value is stored in Text column.

  """

  use Ecto.Adapters.SQL, driver: :firebirdex

  @behaviour Ecto.Adapter.Storage

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

  defp json_decode(x) when is_binary(x), do: {:ok, Firebird.json_library().decode!(x)}
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
