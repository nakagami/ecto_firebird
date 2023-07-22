defmodule Ecto.Adapters.Firebird.DataType do
  @moduledoc false

  @spec column_type(atom(), Keyword.t()) :: String.t()
  def column_type(:id, _opts), do: "INTEGER"
  def column_type(:serial, _opts), do: "INTEGER"
  def column_type(:bigserial, _opts), do: "BIGINT"
  def column_type(:bigint, _opts), do: "BIGINT"
  def column_type(:float, _opts), do: "NUMERIC"
  def column_type(:binary, _opts), do: "BLOB SUB_TYPE 0"
  def column_type(:map, _opts), do: "BLOB SUB_TYPE 1"
  def column_type(:array, _opts), do: "BLOB SUB_TYPE 1"
  def column_type({:map, _}, _opts), do: "TEXT"
  def column_type({:array, _}, _opts), do: "BLOB SUB_TYPE 1"
  def column_type(:utc_datetime, _opts), do: "TIMESTAMP WITH TIMEZONE"
  def column_type(:utc_datetime_usec, _opts), do: "TIMESTAMP WITH TIMEZONE"
  def column_type(:naive_datetime, _opts), do: "TIMESTAMP"
  def column_type(:naive_datetime_usec, _opts), do: "TIMESTAMP"
  def column_type(:time, _opts), do: "TIME"
  def column_type(:time_usec, _opts), do: "TIME"
  def column_type(:timestamp, _opts), do: "TIMESTAMP"
  def column_type(:decimal, nil), do: "DECIMAL"

  def column_type(:decimal, opts) do
    # We only store precision and scale for DECIMAL.
    precision = Keyword.get(opts, :precision)
    scale = Keyword.get(opts, :scale, 0)

    if precision do
      "DECIMAL(#{precision},#{scale})"
    else
      "DECIMAL"
    end
  end

  def column_type(:binary_id, _opts), do: "CHAR(36)"
  def column_type(:uuid, _query), do: "CHAR(36)"

  def column_type(:string, opts) do
    size = Keyword.get(opts, :size)

    if size do
      "VARCHAR(#{size})"
    else
      "VARCHAR(255)"
    end
  end

  def column_type(type, _) when is_atom(type) do
    type
    |> Atom.to_string()
    |> String.upcase()
  end

  def column_type(type, _) do
    raise ArgumentError,
          "unsupported type `#{inspect(type)}`. The type can either be an atom, a string " <>
            "or a tuple of the form `{:map, t}` or `{:array, t}` where `t` itself follows the same conditions."
  end
end
