defmodule Ecto.Adapters.Firebird.CodecTest do
  use Ecto.Integration.Case, async: false

  import Ecto.Query

  alias Ecto.Adapters.Firebird.Codec
  alias Ecto.Integration.TestRepo

  # A custom type whose underlying type is :float, like the ones libraries
  # such as Ash define. Ecto skips the adapter loader for a plain :float field
  # when the value already is a float, but not for a custom type, so the
  # loader sees the float a DOUBLE PRECISION or FLOAT column returns.
  defmodule CustomFloat do
    use Ecto.Type
    def type, do: :float
    def cast(value), do: {:ok, value}
    def load(value), do: {:ok, value}
    def dump(value), do: {:ok, value}
  end

  defmodule Measurement do
    use Ecto.Schema

    schema "measurements" do
      field(:amount, CustomFloat)
    end
  end

  test "float_decode/1 accepts a float" do
    assert Codec.float_decode(278.06) == {:ok, 278.06}
    assert Codec.float_decode(Decimal.new("278.06")) == {:ok, 278.06}
    assert Codec.float_decode(2) == {:ok, 2.0}
    assert Codec.float_decode(nil) == {:ok, nil}
  end

  test "a DOUBLE PRECISION column loads into a custom :float type" do
    # Written as a decimal so the stored value does not depend on how the
    # driver encodes float parameters.
    TestRepo.insert_all("measurements", [[amount: Decimal.new("278.06")]])

    assert [%Measurement{amount: 278.06}] = TestRepo.all(Measurement)
    assert TestRepo.all(from(m in Measurement, select: m.amount)) == [278.06]
  end
end
